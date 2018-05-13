require 'fileutils'
require 'aws-sdk-s3'

module Infra::Tools
  class Key
    ROOT = File.join(Infra::ROOT, "keys")
    BUCKET = "#{Infra::S3_PREFIX}-infra-keys"

    def initialize *labels
      @labels = labels
    end

    def local_path
      @local_path ||= File.join(ROOT, s3_key)
    end

    def cached?
      File.exist?(local_path)
    end

    def ensure_cached
      cache unless cached?
    end

    private
    def s3_key
      @s3_key ||= "#{File.join(*@labels)}.key"
    end

    def get_from_s3
      s3 = Aws::S3::Client.new
      response = s3.get_object(
        bucket: BUCKET,
        key:    s3_key)

      response.body.string
    end

    def cache
      FileUtils.mkdir_p File.dirname(local_path)

      key = get_from_s3
      File.open(local_path, 'w') do |f|
        f << key
      end

      FileUtils.chmod 0644, local_path
    end
  end
end
