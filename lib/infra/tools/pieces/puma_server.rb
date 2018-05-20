require 'fileutils'
require 'net/http'

module Infra::Tools::Pieces
  class PumaServer < Piece
    attr_accessor :hostname, :ssl_key_name, :port, :environment

    def initialize config
      super config

      self.ssl_key_name ||= hostname
    end

    def name; "#{service.name}-#{name}"; end
    def systemd_file_path; File.join("/lib/systemd/system", "#{name}.service"); end
    def systemd_link_path; File.join("/etc/systemd/system", "#{name}.service"); end
    def nginx_file_path; File.join("/etc/nginx/sites-available", name); end
    def nginx_link_path; File.join("/etc/nginx/sites-enabled", name); end

    def setup
      # create the nginx site
      puts "creating nginx config"
      local_path = File.join(Infra::ROOT, "nginx", hostname)
      Infra::Tools::Template.from_keys(
        local_path, template_keys, "nginx", "reverse-proxy")
      puts "uploading nginx config"
      self.instance.upload_file(local_path, nginx_file_path)

      # create the systemd service
      puts "creating systemd config"
      local_path = File.join(Infra::ROOT, "systemd", service.name, name)
      FileUtils.mkdir_p File.dirname(local_path)
      Infra::Tools::Template.from_keys(
        local_path, template_keys, "systemd", "puma-server")
      puts "uploading systemd config"
      self.instance.upload_file(local_path, systemd_file_path)

      # create symlinks and restart nginx
      self.instance.with_shell do |shell|
        puts "creating config symlinks"
        shell.exec!("sudo ln -s #{nginx_file_path} #{nginx_link_path}")
        shell.exec!("sudo systemctl enable #{name}")

        puts "restarting nginx"
        shell.exec!("sudo systemctl restart nginx")

        puts "restarting nginx"
        shell.exec!("sudo systemctl start #{name}")
      end

      # test the connection
      response = Net::HTTP.post_response("#{hostname}/.well-known/test")

      return response.code == '200'
    end

    def start
      self.instance.with_shell do |shell|
        puts "starting puma-server systemd service"
        shell.exec!("sudo systemctl start #{systemd_name}")
      end
    end

    def stop
      self.instance.with_shell do |shell|
        # start the systemd process
        shell.exec!("sudo systemctl stop #{systemd_name}")
      end
    end

    # check
    #
    #
    #

    # destroy
    #
    #
    #
  end
end
