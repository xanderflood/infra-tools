require "infra/tools/version"

module Infra
  module Tools
  end
end

%w(template).each do |name|
  require_relative "tools/#{name}"
end
