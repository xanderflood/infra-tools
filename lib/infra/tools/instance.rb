require "yaml"

require "net/ssh"
require "net/scp"

require "aws-sdk-ec2"

require_relative "key"

module Infra::Tools
  class Instance
    attr_accessor :name, :instance_id, :public_ip
    attr_accessor :user, :users, :template_keys

    DEFAULT     = "main"
    SOURCE_PATH = "../infra/config/instances.yaml"

    def self.all
      @@all ||= YAML.load_file(SOURCE_PATH).map do |instance|
        self.new(instance)
      end
    end

    def self.find name
      self.all.find { |instance| instance.name == name }
    end

    def self.default; self.find(DEFAULT); end

    def username; user["username"]; end

    def initialize config
      config.each do |k, v|
        self.send("#{k}=", v)
      end

      self.user = users[user]
    end

    def start
      aws_instance.start
    end

    def stop
      aws_instance.stop
    end

    def status
      fetch_aws_instance.state.name
    end

    def restart
      start && stop
    end

    def as_user(key)
      obj = self.clone
      obj.user = users[key]

      obj
    end

    ##############

    def key_labels
      [name, username]
    end

    def key_file
      return @key_file if @key_file

      key = Key.new key_labels
      key.ensure_cached

      @key_file = key.local_path
    end

    def with_shell &block
      with_connection(Net::SSH, &block)
    end

    def with_filesystem &block
      with_connection(Net::SCP, &block)
    end

    def upload_file local, remote
      with_filesystem do |filesystem|
        filesystem.upload!(local, remote)
      end
    end

    private
    def template_keys_for *labels
      keys = {}
      cur = template_keys
      labels.each do |label|
        cur = cur[label]

        keys.merge(cur.select { |_, v| v.is_a? String })
      end

      keys
    end

    def with_connection klass, &block
      klass.start(
        public_ip, username,
        keys: [key_file],
        &block)
    end

    def aws_instance # may lead to outdated state information
      @aws_instance ||= fetch_aws_instance
    end

    def fetch_aws_instance
      Aws::EC2::Instance.new(id: instance_id)
    end
  end
end
