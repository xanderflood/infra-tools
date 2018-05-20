module Infra::Tools::Connection
  class Base
    attr_accessor :logger

    def initialize(logger=nil)
      self.logger = logger || Logger.new(STDOUT)
    end
  end
end
