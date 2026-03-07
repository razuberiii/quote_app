class ActionItem < ApplicationRecord
  ACTION_TYPES = %w[
    quote_viewed
    quote_not_viewed
    quote_expiring
    revision_requested
  ].freeze

  belongs_to :user
  belongs_to :reference, polymorphic: true

  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :reference_type, :reference_id, presence: true

  scope :unresolved, -> { where(resolved_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def resolved?
    resolved_at.present?
  end

  def message
    case action_type
    when "quote_viewed"
      "Buyer viewed #{reference_label}. Follow up while momentum is warm."
    when "quote_not_viewed"
      "#{reference_label} has not been viewed for 3 days after sending."
    when "quote_expiring"
      "#{reference_label} is close to expiry."
    when "revision_requested"
      "Buyer requested changes on #{reference_label}."
    else
      reference_label
    end
  end

  def headline
    return quote_display_name if reference.is_a?(Quote)

    reference_label
  end

  def secondary_text
    return "#{reference.quote_no} • #{message}" if reference.is_a?(Quote)

    message
  end

  def reference_label
    return reference.quote_no if reference.respond_to?(:quote_no)
    return reference.name if reference.respond_to?(:name)

    reference_type.to_s
  end

  def link_path
    return Rails.application.routes.url_helpers.quote_path(reference) if reference.is_a?(Quote)
    return Rails.application.routes.url_helpers.customer_path(reference) if reference.is_a?(Customer)

    "#"
  end

  def priority
    return :urgent if action_type == "quote_expiring"
    return :watch if action_type == "revision_requested"
    return :watch if action_type == "quote_viewed"

    :normal
  end

  def priority_rank
    { urgent: 0, watch: 1, normal: 2 }.fetch(priority, 3)
  end

  private

  def quote_display_name
    return reference.custom_title if reference.respond_to?(:custom_title) && reference.custom_title.present?

    first_item = reference.quote_items.ordered.first if reference.respond_to?(:quote_items)
    first_item&.product&.name.presence ||
      first_item&.description.presence ||
      reference.quote_no
  end
end
