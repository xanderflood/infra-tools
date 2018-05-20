module Infra::Tools
  class Template
    def self.template_path *keys
      f = File.join("templates", *keys)
      "#{f}.template"
    end

    def self.from_keys path, substitutions, *keys
      File.open(template_path(*keys), 'r') do |ifile|
        File.open(path, 'w') do |ofile|
          self.new(ifile, ofile).apply(substitutions)
        end
      end
    end

    def initialize istream, ostream
      @istream = istream
      @ostream = ostream
    end

    def apply substitutions
      @template ||= @istream.read

      result = @template
      substitutions.each do |k, v|
        result = result.gsub("{{{#{k}}}}", v.to_s)
      end

      @ostream.write(result)
      nil
    end
  end
end
