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
      def open3(command, loud=false)
        self.logger.info("executing command: #{command}")

        self.contexts.each.with_index do |i, context|
          self.logger.info("#{i}\t#{context.description}")
        end

        # TODO: find some way to StringIO data into the user-provided block,
        # so that it can match the open3 signature
        value = nil
        prepped = Context.apply(command)
        channel = ssh.open_channel do |ch|
          ch.exec prepped do |ch, success|
            raise "could not start command" unless success

            channel.on_close do
              self.logger.info("command finished")
            end

            session = Session.new(ch)

            # user-provided block can call the
            # following methods on the session:
            # (1) outline - read stdout until \n or EOF
            # (2) errline - read stderr until \n or EOF
            #  ^-- these return nil when the process is finished and no more data remains
            # (3) write   - write to stdin
            # (4) wait    - block until process exits
            # (5) value   - return exit status
            # (5) signal  - return exit signal
            yield session

            session.wait
            value = session.value
          end
        end

        (value == 0)
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
        result = nil
        exec(command, loud) do |session|
          yield session if block_given?

          result += data while (data = session.readline)
        end
        result
      end

      class Session
        attr_accessor :channel
        attr_accessor :stdout_buffer, :stderr_buffer, :fresh
        attr_accessor :alive, :status, :signal

        def initialize channel
          self.channel = channel

          self.stdout_buffer = ""
          channel.on_data do |_, data|
            self.stdout_buffer += data
            self.fresh = true
          end

          self.stderr_buffer = ""
          channel.on_extended_data do |ch,type,data|
            self.stderr_buffer += data
            self.fresh = true
          end

          channel.on_request("exit-status") do |_,data|
            self.status = data.read_long
          end

          channel.on_request("exit-signal") do |_, data|
            self.signal = data.read_long
          end

          self.alive = true
          channel.on_close do
            self.alive = false
          end
        end

        def write string
          self.channel.send_data string
          nil
        end

        def wait
          while self.alive; end
        end

        def self.outline; readline(:stdout); end
        def self.errline; readline(:stderr); end

        def self.readline(buffer_name)
          var_sym = :"#{buffer_name}_buffer"
          buffer = self.send(var_sym)

          if !buffer.include? "\n"
            until !self.alive && self.fresh && buffer.include?("\n")
              self.fresh = false
            end
          end

          if !self.alive && buffer.empty?
            return nil
          end

          io = StringIO.new(buffer)
          line = io.readline
          self.send(:"#{var_sym}=", io.read)

          line
        end
      end
    end
  end
end
