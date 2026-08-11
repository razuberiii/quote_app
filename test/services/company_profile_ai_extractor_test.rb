require "test_helper"

class CompanyProfileAiExtractorTest < ActiveSupport::TestCase
  test "company profile schema accepts explicit nulls and rejects unknown fields" do
    payload = {
      "company" => {
        "name" => "Rubus Machinery", "legal_name" => nil, "registration_number" => nil,
        "registration_details" => nil, "email" => nil, "phone" => nil, "address" => nil,
        "website" => nil, "business_type" => nil, "evidence_ids" => [ "e1" ]
      },
      "warnings" => [ "法定名称未找到" ],
      "evidence" => [ { "id" => "e1", "field_path" => "company.name", "excerpt" => "Rubus Machinery",
        "source" => "profile", "location" => nil } ]
    }

    assert StructuredSchemas.validate!(payload, StructuredSchemas::COMPANY_PROFILE)
    payload["company"]["invented_field"] = "not allowed"
    assert_raises(ArgumentError) { StructuredSchemas.validate!(payload, StructuredSchemas::COMPANY_PROFILE) }
  end

  test "explicit field lines remain importable when structured AI is unavailable" do
    profile_import = CompanyProfileImport.new(company: companies(:one), created_by: users(:one), source_text: "test")
    result = CompanyProfileAiExtractor.new(profile_import).send(:deterministic_fallback, <<~TEXT,
        对外名称：NorthPeak Automation
        法定名称：深圳市北峰自动化设备有限公司
        注册编号：91440300TEST202607
        商务邮箱：export@northpeak-automation.example
        联系电话：+86 755 5550 2188
        网站：https://northpeak-automation.example
      TEXT
      StructuredAiClient::ResponseError.new("empty response"))

    assert_equal "NorthPeak Automation", result.dig("company", "name")
    assert_equal "深圳市北峰自动化设备有限公司", result.dig("company", "legal_name")
    assert_equal "export@northpeak-automation.example", result.dig("company", "email")
    assert_equal 6, result["evidence"].size
    assert result["warnings"].first.include?("字段：值")
  end

  test "explicit field lines become deterministic candidates before AI" do
    profile_import = CompanyProfileImport.new(company: companies(:one), created_by: users(:one), source_text: "test")
    candidates = CompanyProfileAiExtractor.new(profile_import).send(:deterministic_candidates, <<~TEXT)
      对外名称：NorthPeak Automation
      商务邮箱：export@northpeak.example
      Unstructured marketing copy
    TEXT

    assert_equal "NorthPeak Automation", candidates.dig("name", "value")
    assert_equal "export@northpeak.example", candidates.dig("email", "value")
    assert_nil candidates["phone"]
  end
end
