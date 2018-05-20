module Infra::Tools::Pieces
  class Environment < Piece
    attr_accessor :username, :repository, :repository_name, :revision
    attr_accessor :ruby_version, :gemset

    def initialize config
      super config

      self.revision     ||= "master"
      self.username     ||= name
      self.repository   ||= "xanderflood/#{name}"
      self.repository_name = File.basename(repository)

      self.ruby_version ||= "2.4"
      self.gemset       ||= name
    end

    def setup
      self.instance.with_shell do |shell|
        puts "adding user"
        output = shell.exec!("sudo adduser #{username}")
        
        puts "installing curl and git-core"
        output = shell.exec!("sudo apt-get install -y curl git-core")

        puts "cloning repository"
        output = shell.exec!("sudo su #{username} -c \"git clone git@github.com/#{repository}\"")

        puts "uploading RVM install script"
        local_path = Infra::Tools::Template.template_path(
          "scripts", "rvm")
        remote_path = "/home/#{username}/rvm"
        self.instance.upload_file(local_path, remote_path)
        output = shell.exec!("sudo chmod +x #{remote_path}")

        puts "installing rvm"
        output = shell.exec!("sudo su #{username} -c \"cd && bash < <(curl -sk https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)\"")

        # install ruby dependencies
        puts "installing ruby"
        output = shell.exec!("sudo su #{username} -c \"cd && ~/.rvm/scripts/rvm install #{ruby_version}\"")
        puts "installing bundler"
        output = shell.exec!("sudo su #{username} -c \"cd && ~/.rvm/scripts/rvm #{ruby_version} do gem install bundler\"")
        puts "installing gems"
        output = shell.exec!("sudo su #{username} -c \"cd ~/#{repository_name} && ~/.rvm/scripts/rvm #{ruby_version} do bundle install\"")
      end
    rescue => e
      require 'pry'; binding.pry
    end

    def destroy
      # TODO
      fail("Infra::Tools::Pieces::Environment#destroy - not yet implemented")
    end

    def create; end
    def start; end
    def stop; end
  end
end
