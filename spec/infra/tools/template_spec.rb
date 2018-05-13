require 'stringio'

RSpec.describe Infra::Tools::Template do
  describe "#apply" do
    let(:istream) { StringIO.new template_str }
    let(:ostream) { StringIO.new }
    let(:template) { Infra::Tools::Template.new(istream, ostream) }

    subject(:result) do
      template.apply(substitutions)
      ostream.string
    end

    context "when no substitutions are given" do
      let(:substitutions) { {} }
      let(:template_str) { "this string {{{}}} will not be changed {{{k}}}" }

      it "returns the contents of the stream" do
        expect(result).to eq(template_str)
      end
    end

    context "when substitutions are given" do
      let(:substitutions) {
        {
          verb: "do",
          noun: "nouns"
        }
      }
      let(:template_str) { "gonna {{{verb}}} some {{{noun}}}" }

      it "modifies the template appropriately" do
        expect(result).to eq("gonna do some nouns")
      end
    end
  end
end
