require "stringio"
require "net/ssh"

module Infra::Tools::Connection
  class SSH < Base
    attr_accessor :ipv4, :username, :key_file

    def initialize config
      super(nil)

      config.each do |k, v|
        self.send("#{k}=", v)
      end
    end

    def do &block
      Net::SSH.start(
        ipv4,
        username,
        keys: [key_file]
      ) do |shell|
        yield self.dsl(shell)
      end
    end

    def dsl(shell); DSL.new(self, shell); end

    class RemoteCommandError < StandardError; end

    class DSL
      attr_accessor :parent, :shell
      attr_accessor :contexts

      def initialize parent, shell
        self.shell = shell
        self.parent = parent
        self.contexts = []
      end

      def logger; self.parent.logger; end

      def via *contexts, &block
        contexts.each do |context|
          unless context.is_a? Context::Base
            puts "#{context} is not a valid Context object"
            return false
          end
        end

        dsl = parent.dsl(shell)
        dsl.contexts = self.contexts + contexts

        yield(dsl)
        dsl
      end

      # execute a command and return its return true/false success
      def exec(command, loud=false, &block)
        self.logger.info("executing command: #{command}")

        self.logger.info("with contexts:") if self.contexts.any?
        self.contexts.each.with_index do |context, i|
          self.logger.info("(#{i})\t#{context.description}")
        end

        prepped = Context.apply(command, *self.contexts)

        session = nil
        Net::SSH.start(parent.ipv4, parent.username, keys: [parent.key_file]) do |ssh|
          channel = ssh.open_channel do |ch|
            ch.exec(prepped) do |ch, success|
              raise "could not start command" unless success

              session = Session.new(channel, ch, logger)

              yield(session.stdout, session.stderr, session.stdin, session) if block_given?

              session.close
            end
          end

          channel.wait
        end

        session.status
      end

      # execute a command and fail if it returns a non-normal result
      def exec!(command, loud=false, &block)
        result = ""
        status = exec(command, loud) do |stdout, stderr, stdin, session|
          yield if block_given?

          Thread.new do
            result = stderr.read
          end
        end

        if status != 0
          warn result
          raise RemoteCommandError.new("command failed: #{command}") unless status == 0
        end
        true
      end

      # execute a command and return its stdout
      # if the provided block reads from stdin,
      # this method will only return the unread
      # portion
      def eval(command, loud=false)
        result = ""
        exec(command, loud) do |stdout, stderr, stdin, session|
          yield(stdout, stderr, stdin, session) if block_given?

          Thread.new do
            result = stdout.read
          end
        end
        result
      end

      class Session
        class ChannelWriter < IO
          attr_accessor :ch
          def initialize ch
            self.ch = ch
          end

          def write(text="")
            ch.send_data(text)
          end

          def eof!
            ch.eof!
          end
        end

        attr_accessor :stdout, :stderr, :stdin
        attr_accessor :status, :signal, :alive

        def initialize channel, ch, logger
          @channel = channel
          @ch = ch

          self.stdout, @stdout_w = IO.pipe
          self.stderr, @stderr_w = IO.pipe
          self.stdin = ChannelWriter.new(ch)

          ### state tracking ###
          ch.on_request("exit-status") do |_, data|
            self.status = data.read_long

            if self.status == 0
              logger.info("command finished")
            else
              logger.info("command failed")
            end
          end

          ch.on_close do
            @stdout_w.close
            @stderr_w.close
          end

          ### io tracking ###
          ch.on_data do |_, data|
            @stdout_w << data
          end

          ch.on_extended_data do |_, _, data|
            @stderr_w << data
          end
        end

        def wait
          @channel.wait
        end

        def close
          @ch.eof!
        end
      end
    end
  end
end
