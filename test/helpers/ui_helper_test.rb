require "test_helper"

class UiHelperTest < ActionView::TestCase
  include UiHelper

  test "quote status badge maps business state to color classes" do
    html = quote_status_badge("won")

    assert_includes html, "Won"
    assert_includes html, "app-status-badge--green"
  end

  test "customer status badge uses customer label and mapped color" do
    customer = customers(:one)
    customer.status = "contacted"

    html = customer_status_badge(customer)

    assert_includes html, "Contacted"
    assert_includes html, "app-status-badge--indigo"
  end

  test "ui button classes use mapped variant classes" do
    classes = ui_button_classes(:secondary, "w-full")

    assert_includes classes, "app-ui-button"
    assert_includes classes, "app-ui-button--secondary"
    assert_includes classes, "border-slate-200"
    assert_includes classes, "w-full"
  end
end
