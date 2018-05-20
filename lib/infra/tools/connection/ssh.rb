require "net/ssh"

module Infra::Tools::Connection
  class SSH < Base
    attr_accessor :ipv4, :username, :key_file

    def initialize config
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
        yield DSL.new(shell)
      end
    end

    class DSL
      attr_accessor :shell
      attr_accessor :contexts

      def initialize shell
        self.shell = shell
      end

      def via *contexts, &block
        dsl = DSL.new(shell)
        dsl.contexts = self.contexts + contexts

        yield(dsl)
        nil
      end

      # always use Contect.apply(command, self.contexts)
      def open3(command)

        # do this first
      end

      def exec(command)
      end

      def exec!(command)
      end

      def eval(command)
      end

      def eval!(command)
      end
    end
  end
end
