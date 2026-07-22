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
end
