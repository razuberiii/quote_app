require_relative "application_system_test_case"

class PublicQuoteCredentialsTest < ApplicationSystemTestCase
  setup do
    @quote = quotes(:one)
    @quote.update!(status: "sent", sent_at: 3.days.ago)
    @quote.company.company_documents.create!(
      title: "ISO 9001 Certificate",
      document_type: "certificate",
      file: Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/credential.txt"), "text/plain")
    )
    @share = QuoteShare.create!(company: @quote.company, quote: @quote, token: QuoteShare.generate_token, snapshot: QuoteSnapshotBuilder.new(@quote).as_json)
  end

  test "public quote share shows company credentials" do
    visit public_quote_share_path(@share.token)

    assert_text "Company Credentials"
    assert_text "ISO 9001 Certificate"
    assert_link "Download"
  end
end
