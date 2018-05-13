require 'net/ssh'
require 'net/scp'

require_relative "key"

module Infra::Tools
  class Instance
    attr_accessor :name, :public_ip, :user
    attr_accessor :users
    attr_accessor :template_keys

    def username; user["username"]; end

    def initialize config
      config.each do |k, v|
        self.send("#{k}=", v)
      end

      self.user = users[user]
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
  end
end
