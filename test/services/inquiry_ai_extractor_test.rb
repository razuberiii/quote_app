require "test_helper"

class InquiryAiExtractorTest < ActiveSupport::TestCase
  FakeSuccess = Struct.new(:body) do
    def is_a?(type) = type == Net::HTTPSuccess
    def code = "200"
  end

  class FakeHttp
    attr_reader :request

    def initialize(content)
      @content = content
    end

    def start(*)
      connection = Object.new
      content = @content
      connection.define_singleton_method(:request) do |request|
        @captured_request = request
        FakeSuccess.new({ choices: [{ message: { content: content.to_json } }] }.to_json)
      end
      yield connection
    end
  end

  test "normalizes a structured inquiry without inventing commercial amounts" do
    provider = FakeHttp.new({
      "customer" => "Pacific Trading", "currency" => "usd",
      "products" => [{ "name" => "Pump HZ-240", "quantity" => 5, "unit" => "pcs" }],
      "commercial_terms" => { "destination" => "Long Beach" },
      "questions" => ["Which voltage is required?"]
    })

    result = InquiryAiExtractor.new(api_key: "test", base_url: "https://example.test/v1", http_client: provider)
      .extract(source_text: "Need five pumps", source_type: "email")

    assert_equal "Pacific Trading", result["customer"]
    assert_equal "USD", result["currency"]
    assert_equal 5, result.dig("products", 0, "quantity")
    assert_nil result.dig("products", 0, "price")
  end
end
