require 'shellwords'

module Infra::Tools::Connection
  class Context
    def self.apply(command, *contexts)
      contexts.each do |c|
        command = c.format(command)
      end

      command
    end

    # subclasses must define
    # def format command; end

    # execute in the default context
    class Default < Context
      def self.[]; self.new; end

      def format command
        command
      end
    end

    # execute as root
    class Sudo < Context
      def self.[]; self.new; end

      def format command; "sudo #{command}"; end
    end

    # execute as another user
    class SudoSu < Context
      attr_accessor :username

      # if username is nil, this is a simple sudo
      def self.[](username); a = self.new(username: username); end

      def format command
        "sudo su #{username} -c #{escape(command)}"
      end
    end

    # execute in a bundler context
    class Bash < Context
      def self.[]; self.new; end

      def format command; "bash -c #{escape(command)}"; end
    end

    # execute with envars loaded from a hash
    class WithEnvHash < Context
      attr_accessor :env

      def self.[](env); self.new(env: env); end

      def env_string
        @env_string ||= env
        .map { |k,v| "#{k}=#{v}" }
        .join(" ")
      end

      def format command
        "#{env_string} #{command}"
      end
    end

    # execute in a bundler context
    class WithEnvFile < Context
      attr_accessor :path

      def self.[](path); self.new(path: path); end
      
      def format command
        "source #{escape(path)} && #{command}"
      end
    end

    # execute in a bundler context
    class In < Context
      attr_accessor :path

      def self.[](path); self.new(path: path); end

      def format command
        "cd #{escape(path)} && #{command}"
      end
    end

    # execute in a bundler context
    class Bundler < Context
      def self.[]; self.new(path: path); end

      def format command; "bundle exec #{command}"; end
    end

    # execute in a bundler context
    class RVM < Context
      attr_accessor :rvm_path, :ruby, :gemset

      RVM_PATH = "/usr/share/rvm/bin/rvm"

      def self.[](params={}); self.new(params); end

      def prepare
        self.rvm_path ||= RVM_PATH
        self.ruby     ||= "`cat .ruby-version | sed -e 's/^ *//g;s/ *$//g;/^$/d'`"
        self.gemset   ||= "`cat .ruby-gemset | sed -e 's/^ *//g;s/ *$//g;/^$/d'`"
      end

      def format command
        prepare

        "#{rvm_path} #{ruby}@#{gemset} do #{command}"
      end
    end

    # applies the current envar AWS config to the remote shell
    class AWS < Context
      def self.[]
        WithEnvHash[
          AWS_DEFAULT_REGION:    ENV["AWS_DEFAULT_REGION"],
          AWS_SECRET_ACCESS_KEY: ENV["AWS_SECRET_ACCESS_KEY"],
          AWS_ACCESS_KEY_ID:     ENV["AWS_ACCESS_KEY_ID"],
        ]
      end
    end

    private
    def initialize params={}
      params.each do |k, v|
        self.send("#{k}=", v)
      end
    end

    def escape str
      Shellwords.escape(str)
    end
  end
end
