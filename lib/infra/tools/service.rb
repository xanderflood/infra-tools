module Infra::Tools
  class Service
    attr_accessor :name, :pieces

    SOURCE_PATH = "../infra/config/services.yaml"

    def self.all
      @@all ||= YAML.load_file(SOURCE_PATH).map do |service|
        self.new(service)
      end
    end

    def self.find name
      self.all.find { |service| service["name"] == name }
    end

    def username; user["username"]; end

    def initialize config
      config.each do |k, v|
        self.send("#{k}=", v)
      end

      self.pieces ||= {}
      self.pieces = self.pieces.map do |piece|
        type = piece.delete "type"
        Pieces::CLASSES[type].new piece
      end
    end

    def setup
      self.pieces.each(&:setup)
    end

    def start
      self.pieces.each(&:start)
    end

    def stop
      self.pieces.each(&:stop)
    end
  end
end
