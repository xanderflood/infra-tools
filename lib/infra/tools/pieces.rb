module Infra::Tools
  module Pieces
  end
end

%w(piece puma_server environment).each do |name|
  require_relative("pieces/#{name}")
end

module Infra::Tools::Pieces
  CLASSES = {
    "environment" => Infra::Tools::Pieces::Environment,
    "puma-server" => Infra::Tools::Pieces::PumaServer
  }
end
