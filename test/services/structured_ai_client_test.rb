require "test_helper"

class StructuredAiClientTest < ActiveSupport::TestCase
  class FakeHttp
    class << self
      attr_reader :options

      def start(_host, _port, **options)
        @options = options
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.instance_variable_set(:@read, true)
        response.body = {
          choices: [ { message: { content: '{"name":"Atlas"}' } } ],
          usage: { prompt_tokens: 5, completion_tokens: 3 }
        }.to_json
        yield Object.new.tap { |client| client.define_singleton_method(:request) { |_request| response } }
      end
    end
  end

  test "uses the extended configurable AI timeouts" do
    company = companies(:one)
    client = StructuredAiClient.new(company:, source_record: quotes(:one), analysis_type: "timeout_contract",
      schema: { "type" => "object", "properties" => { "name" => { "type" => "string" } },
        "required" => [ "name" ], "additionalProperties" => false },
      system_prompt: "Extract", api_key: "test", http_client: FakeHttp)

    client.call("new timeout input")

    assert_equal StructuredAiClient::DEFAULT_OPEN_TIMEOUT, FakeHttp.options[:open_timeout]
    assert_equal StructuredAiClient::DEFAULT_READ_TIMEOUT, FakeHttp.options[:read_timeout]
  end
end
