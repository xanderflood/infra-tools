require 'aws-sdk-ec2'

module Infra::Tools
  class IPAddress
    SOURCE_PATH = "../infra/config/eip.yaml"

    attr_reader :ipv4, :instance, :instance_id

    def self.all
      @@all ||= YAML.load_file(SOURCE_PATH).map do |config|
        self.new(config)
      end
    end

    def initialize config
      unless (config.keys - ["ipv4", "instance_id"]).empty?
        raise StandardError.new("invalid config keys for ip_address: #{config}")
      end

      unless config["ipv4"]
        raise StandardError.new("missing `ipv4` key for ip_address: #{config}")
      end

      @ipv4 = config["ipv4"]

      iid = config.delete("instance_id")
      if iid
        self.instance_id = iid
      end

      @instance = Instance.find(@instance_id)
    end

    def instance=(obj)
      @instance = obj
      @instance_id = @instance.instance_id
    end

    def instance_id=(id)
      @instance_id = id
      @instance = Instance.find(@instance_id)
    end

    def allocation_id
      # require 'pry'; binding.pry
      @allocation_id ||= ec2_model.allocation_id
    end

    def associate!(instance)
      self.class.ec2.associate_address(
        {
          allocation_id: allocation_id,
          instance_id: instance.instance_id,
        }
      )
    end

    private
    def self.ec2
      @ec2 ||= Aws::EC2::Client.new
    end

    def self.ec2_query
      @query ||= ec2.describe_addresses.addresses
    end

    def self.find ipv4
      self.ec2_query.find { |address| address.public_ip == ipv4 }
    end

    def ec2_model
      @ec2_model ||= self.class.find(@ipv4)
    end
  end
end
