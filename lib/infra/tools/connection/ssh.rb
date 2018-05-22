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
        nil
      end

      # execute a command and return its return true/false success
      def exec(command, loud=false, &block)
        self.logger.info("executing command: #{command}")

        self.contexts.each.with_index do |i, context|
          self.logger.info("#{i}\t#{context.description}")
        end

        # TODO: find some way to StringIO data into the user-provided block,
        # so that it can match the open3 signature
        prepped = Context.apply(command)
        status = nil
        Net::SSH.start(parent.ipv4, parent.username, keys: [parent.key_file]) do |ssh|
          channel = ssh.open_channel do |ch|
            ch.exec(prepped) do |ch, success|
              raise "could not start command" unless success

              stdout_read, stdout_write = IO.pipe
              stderr_read, stderr_write = IO.pipe
              stdin = ChannelWriter.new(ch)

              ### state tracking ###
              ch.on_request("exit-status") do |_, data|
                status = data.read_long
              end

              alive = true
              ch.on_close do
                self.logger.info("command finished")

                stdout_write.close
                stderr_write.close
              end

              ### io tracking ###
              ch.on_data do |_, data|
                stdout_write << data
              end

              ch.on_extended_data do |_, _, data|
                stderr_write << data
              end

              yield(stdout_read, stderr_read, stdin, ch) if block_given?
            end
          end

          channel.wait
        end

        (status == 0)
      end

      # execute a command and fail if it returns a non-normal result
      def exec!(command, loud=false, &block)
        success = exec(command, loud, &block)

        raise RemoteCommandError.new("command failed: #{command}") unless success
        true
      end

      # execute a command and return its stdout
      # if the provided block reads from stdin,
      # this method will only return the unread
      # portion
      def eval(command, loud=false)
        result = ""
        exec(command, loud) do |stdout, stderr, stdin, ch|
          yield(stdout, stderr, stdin, ch) if block_given?

          Thread.new do
            until stdout.eof?
              result += stdout.readline
            end
          end
        end
        result
      end

      class ChannelWriter < IO
        attr_accessor :ch
        def initialize ch
          self.ch = ch
        end

        def write text
          ch.send_data(text)
        end
      end
    end
  end
end
