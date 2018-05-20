require "logger"

module Infra::Tools
  module Connection
  end
end

%w(base ssh scp context).each do |name|
  require_relative "connection/#{name}"
end
