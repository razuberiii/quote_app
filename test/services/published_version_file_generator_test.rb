require "test_helper"

class PublishedVersionFileGeneratorTest < ActiveSupport::TestCase
  test "customer-ready Excel is generated from the immutable snapshot" do
    quote = quotes(:one)
    revision = quote.quote_revisions.create!(company: quote.company, number: 7, status: "current",
      currency: quote.currency, total: quote.grand_total, snapshot: QuoteSnapshotBuilder.new(quote).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    output = PublishedVersionFileGenerator.new(revision).excel

    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", output.content_type
    assert_operator output.byte_size, :>, 4_000
    assert output.filename.end_with?("-V7.xlsx")
    assert_equal "PK", output.io.read(2)
  end

  test "customer-ready PDF is generated from the immutable snapshot" do
    quote = quotes(:one)
    revision = quote.quote_revisions.create!(company: quote.company, number: 8, status: "current",
      currency: quote.currency, total: quote.grand_total, snapshot: QuoteSnapshotBuilder.new(quote).as_json,
      secure_token: SecureRandom.urlsafe_base64(16), published_at: Time.current)

    output = PublishedVersionFileGenerator.new(revision).pdf

    assert_equal "application/pdf", output.content_type
    assert_operator output.byte_size, :>, 8_000
    assert_equal "%PDF", output.io.read(4)
  end
end
