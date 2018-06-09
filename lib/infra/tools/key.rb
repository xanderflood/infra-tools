require 'fileutils'
require 'aws-sdk-s3'
require 'openssl'

module Infra::Tools
  class Key
    ROOT = File.join(Infra::ROOT, "keys")
    BUCKET = "#{Infra::S3_PREFIX}-infra-keys"

    attr_reader :labels, :name

    def self.find(*labels)
      self.query.find{ |kp| kp.key_name == File.join(*labels) }
    end

    def initialize *labels
      @labels = labels
    end

    def name
      File.join(*@labels)
    end

    ### local caching ###
    def local_path(ext)
      File.join(ROOT, s3_key(ext))
    end

    def cached?
      File.exist?(local_path('pub')) && File.exist?(local_path('key'))
    end

    def ensure_cached
      unless cached?
        pub, key = get_from_s3

        cache_local(pub, key)
      end
    end

    ### s3 caching ###
    def s3_key(ext)
      "#{self.name}.#{ext}"
    end

    def exist?
      !self.class.find(self.name).nil?
    end

    ### management ###
    def create(force=false)
      fail("key already exists: #{self.name}") if self.exist? && !force

      pub, key = self.class.generate_keys

      base64 = pub.split("\n")[1..-2].join

      self.class.ec2.import_key_pair(
        key_name: name,
        public_key_material: base64)

      cache_local(pub, key)
      cache_to_s3(pub, key)

      nil
    end

    # not supported:
    # destroy
    # start
    # stop

    private
    def cache_to_s3(pub, key)
      s3 = Aws::S3::Client.new
      s3.put_object(
        bucket: BUCKET,
        key:    s3_key('pub'),
        body:   pub)
      s3.put_object(
        bucket: BUCKET,
        key:    s3_key('key'),
        body:   key)

      # TODO: server-side encryption
      nil
    end

    def get_from_s3
      s3 = Aws::S3::Client.new
      pub_response = s3.get_object(
        bucket: BUCKET,
        key:    s3_key('pub'))
      prv_response = s3.get_object(
        bucket: BUCKET,
        key:    s3_key('key'))

      return pub_response.body.string, prv_response.body.string
    end

    def ensure_dir
      FileUtils.mkdir_p File.dirname(local_path('pub'))
    end

    def cache_local(pub=nil, key=nil)
      ensure_dir

      open local_path('pub'), 'w' do |io|
        io.write pub
      end
      open local_path('key'), 'w' do |io|
        io.write key
      end

      FileUtils.chmod 0600, local_path('pub')
      FileUtils.chmod 0600, local_path('key')

      nil
    end

    def self.generate_keys(passphrase=nil)
      key = OpenSSL::PKey::RSA.new 2048

      public_key = key.public_key.to_pem
      private_key = if passphrase
        cipher = OpenSSL::Cipher.new 'AES-128-CBC'
        key.to_pem cipher, passphrase
      elsif
        key.to_pem
      end

      return public_key, private_key
    end

    def self.ec2
      Aws::EC2::Client.new
    end

    def self.query
      @query ||= ec2.describe_key_pairs.key_pairs
    end
  end
end
