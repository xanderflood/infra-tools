module Infra::Tools::Pieces
  class Piece
    attr_accessor :name
    attr_accessor :service
    attr_accessor :instance

    def initialize config
      config.each do |k, v|
        self.send("#{k}=", v)
      end

      self.instance = Infra::Tools::Instance.find(self.instance) if self.instance.is_a? String
      self.instance ||= Infra::Tools::Instance.default
    end

    def template_keys
      @template_keys ||= self.instance.template_keys_for name
    end
  end
end
