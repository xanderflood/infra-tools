require 'shellwords'

module Infra::Tools::Connection
  module Context
    def self.apply(command, *contexts)
      contexts.reverse.each do |c|
        command = c.format(command)
      end

      command
    end

    # subclasses must define
    # def format command; end

    class Base
      attr_accessor :override_name, :override_desc

      # should be overridden, but this is a reasonable default
      def description
        override_desc || self.to_s
      end

      def name
        override_name || self.class.name.split("::").last
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

    # execute in the default context
    class Default < Base
      def self.[]; self.new; end

      def format command
        command
      end
    end

    # execute as root
    class Sudo < Base
      def self.[]; self.new; end

      def format command; "sudo #{command}"; end

      def description
        "as superuser"
      end
    end

    # execute as another user
    class SudoSu < Base
      attr_accessor :username

      # if username is nil, this is a simple sudo
      def self.[](username); a = self.new(username: username); end

      def format command
        "sudo su #{username} -c #{escape(command)}"
      end

      def description
        "as user #{username}"
      end
    end

    # execute in a bundler context
    class Bash < Base
      def self.[]; self.new; end

      def format command; "bash -c #{escape(command)}"; end

      def description
        "in a bash session"
      end
    end

    # execute with envars loaded from a hash
    class WithEnvHash < Base
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

      def description
        "with #{env_string}"
      end
    end

    # execute in a bundler context
    class WithEnvFile < Base
      attr_accessor :path

      def self.[](path); self.new(path: path); end
      
      def format command
        "source #{escape(path)} && #{command}"
      end

      def description
        "sourcing #{path}"
      end
    end

    # execute in a bundler context
    class In < Base
      attr_accessor :path

      def self.[](path); self.new(path: path); end

      def format command
        "cd #{escape(path)} && #{command}"
      end

      def description
        "in #{path}"
      end
    end

    # execute in a bundler context
    class Bundled < Base
      def self.[]; self.new(); end

      def format command; "bundle exec #{command}"; end

      def description
        "bundled"
      end
    end

    # execute in a bundler context
    class RVM < Base
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
    class AWS < Base
      def self.[]
        w = WithEnvHash[
          AWS_DEFAULT_REGION:    ENV["AWS_DEFAULT_REGION"],
          AWS_SECRET_ACCESS_KEY: ENV["AWS_SECRET_ACCESS_KEY"],
          AWS_ACCESS_KEY_ID:     ENV["AWS_ACCESS_KEY_ID"],
        ]
        
        w.override_name = "AWS"
        w.override_desc = "AWS(local)"
        w
      end
    end
  end
end
