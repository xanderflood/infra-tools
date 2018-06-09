require "infra/tools/version"

module Infra
  ROOT = ENV["INFRA_ROOT"]
  S3_PREFIX = ENV["INFRA_S3_PREFIX"]

  module Tools
  end
end

%w(key instance template pieces service connection ip_address).each do |name|
  require_relative "tools/#{name}"
end
