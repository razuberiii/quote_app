class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :set_primary_image, :remove_primary_image, :remove_gallery_image, :bulk_remove_gallery_images ]
  before_action :set_configurator_presets, only: [ :new, :create, :edit, :update ]

  def index
    @products = current_user.company.products.order(:name)
    @search_query = params[:query]
    @products = @products.where("name ILIKE ?", "%#{@search_query}%") if @search_query.present?

    reference_scope = QuoteItem
      .joins(:quote)
      .where(product_id: @products.select(:id))
      .where(quotes: { company_id: current_user.company_id })
      .where(quotes: { archived_at: nil, deleted_at: nil })

    @product_quote_stats = reference_scope
      .group(:product_id)
      .pluck(:product_id, Arel.sql("COUNT(DISTINCT quotes.quote_no)"), Arel.sql("MAX(quotes.updated_at)"))
      .each_with_object({}) do |(product_id, quote_count, last_used_at), memo|
        memo[product_id] = {
          quote_count: quote_count.to_i,
          last_used_at: last_used_at
        }
      end
  end

  def show
    reference_scope = @product.quote_items
      .joins(quote: :customer)
      .where(quotes: { company_id: current_user.company_id, archived_at: nil, deleted_at: nil })
    @quote_reference_count = reference_scope.distinct.count("quotes.quote_no")
    @last_referenced_at = reference_scope.maximum("quotes.updated_at")
    # DISTINCT ON (quotes.quote_no) picks the latest revision per customer engagement,
    # preventing earlier revisions at different prices from skewing the average.
    dedup_price_sql = reference_scope
      .select("DISTINCT ON (quotes.quote_no) quote_items.unit_price")
      .order("quotes.quote_no, quotes.updated_at DESC")
      .to_sql
    @average_quoted_price = ApplicationRecord.connection
      .select_value("SELECT AVG(unit_price) FROM (#{dedup_price_sql}) AS dedup_prices")
      &.to_f
      &.round(2)
    recent_price_scope = reference_scope
      .select(
        "DISTINCT ON (quotes.quote_no) " \
        "quotes.id AS quote_id, " \
        "quotes.quote_no, " \
        "quotes.custom_title, " \
        "quotes.currency, " \
        "customers.name AS customer_name, " \
        "quote_items.unit_price, " \
        "quote_items.quantity, " \
        "quotes.updated_at"
      )
      .order(Arel.sql("quotes.quote_no, quotes.updated_at DESC"))
    @recent_quoted_prices = QuoteItem
      .from("(#{recent_price_scope.to_sql}) recent_quote_prices")
      .select("recent_quote_prices.*")
      .order("recent_quote_prices.updated_at DESC")
      .limit(10)
  end

  def new
    @product = current_user.company.products.new
  end

  def create
    @product = current_user.company.products.new(product_params)

    unless validate_gallery_upload_selection(@product)
      return render :new, status: :unprocessable_entity
    end

    if @product.save
      attach_uploaded_gallery_images(@product)
      @product.ensure_display_image!
      redirect_to @product, notice: t("products.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "already exists in your product list")
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    if e.message.to_s.downcase.include?("unique") && e.message.to_s.downcase.include?("sku")
      @product.errors.add(:sku, "already exists in your product list")
      render :new, status: :unprocessable_entity
    else
      raise
    end
  end

  def edit
  end

  def update
    unless validate_gallery_upload_selection(@product)
      return render :edit, status: :unprocessable_entity
    end

    if @product.update(product_params)
      attach_uploaded_gallery_images(@product)
      @product.ensure_display_image!
      redirect_to @product, notice: t("products.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "already exists in your product list")
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    if e.message.to_s.downcase.include?("unique") && e.message.to_s.downcase.include?("sku")
      @product.errors.add(:sku, "already exists in your product list")
      render :edit, status: :unprocessable_entity
    else
      raise
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: t("products.flash.deleted")
  end

  def set_primary_image
    attachment = @product.gallery_images.attachments.find_by(id: params[:attachment_id])
    return redirect_to edit_product_path(@product), alert: t("products.flash.image_not_found") unless attachment

    @product.image.attach(attachment.blob)
    redirect_to edit_product_path(@product), notice: t("products.flash.display_image_updated")
  end

  def remove_primary_image
    @product.image.purge_later if @product.image.attached?
    @product.reload
    @product.ensure_display_image!
    redirect_to edit_product_path(@product), notice: t("products.flash.display_image_removed")
  end

  def remove_gallery_image
    attachment = @product.gallery_images.attachments.find_by(id: params[:attachment_id])
    return redirect_to edit_product_path(@product), alert: t("products.flash.image_not_found") unless attachment

    removing_primary = @product.image.attached? && @product.image.blob_id == attachment.blob_id
    attachment.purge_later
    @product.image.purge_later if removing_primary
    @product.reload
    @product.ensure_display_image!
    redirect_to edit_product_path(@product), notice: t("products.flash.gallery_image_removed")
  end

  def bulk_remove_gallery_images
    ids = Array(params[:attachment_ids]).reject(&:blank?).map(&:to_i)
    attachments = @product.gallery_images.attachments.where(id: ids)
    return redirect_to edit_product_path(@product), alert: t("products.flash.no_images_selected") if attachments.blank?

    removing_primary = @product.image.attached? && attachments.any? { |a| a.blob_id == @product.image.blob_id }
    attachments.each(&:purge_later)
    @product.image.purge_later if removing_primary
    @product.reload
    @product.ensure_display_image!

    redirect_to edit_product_path(@product), notice: t("products.flash.images_removed", count: attachments.size)
  end

  private

  def set_product
    @product = current_user.company.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :sku,
      :product_category,
      :unit,
      :description,
      :default_price,
      :price_currency,
      :cost_price,
      :moq,
      :lead_time,
      :default_spec_preset_id,
      :default_addon_preset_id,
      spec_preset_ids: [],
      addon_preset_ids: [],
      default_specs: [ :name, :value ],
      default_addons: [ :name, :price ]
    )
  end

  def set_configurator_presets
    @spec_presets = current_user.company.spec_presets.ordered
    @addon_presets = current_user.company.addon_presets.ordered
  end

  def attach_uploaded_gallery_images(product)
    files = params.dig(:product, :gallery_images).to_a.reject(&:blank?)
    return if files.empty?
    had_display_image = product.display_image.present?

    blobs = files.map do |file|
      io = file.respond_to?(:tempfile) ? file.tempfile : file
      io.rewind if io.respond_to?(:rewind)
      ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: file.original_filename,
        content_type: file.content_type
      )
    end

    # Append-only behavior: keep existing images and attach only newly uploaded files.
    product.gallery_images.attach(blobs)

    raw_index = params.dig(:product, :primary_uploaded_image_index)
    selected_index = Integer(raw_index, exception: false) unless raw_index.blank?
    if selected_index && selected_index.between?(0, blobs.length - 1)
      product.image.attach(blobs[selected_index])
      return
    end

    # If there was no display image at all, default the first uploaded image as display.
    product.image.attach(blobs.first) unless had_display_image
  end

  def validate_gallery_upload_selection(product)
    files = params.dig(:product, :gallery_images).to_a.reject(&:blank?)
    return true if files.empty?

    if files.size > Product::MAX_GALLERY_UPLOAD_PER_REQUEST
      product.errors.add(:gallery_images, "can upload up to #{Product::MAX_GALLERY_UPLOAD_PER_REQUEST} images per request")
      return false
    end

    existing_count = product.gallery_images.attachments.size
    if existing_count + files.size > Product::MAX_GALLERY_IMAGES
      product.errors.add(:gallery_images, "can have up to #{Product::MAX_GALLERY_IMAGES} images")
      return false
    end

    files.each do |file|
      content_type = file.content_type.to_s
      byte_size = file.respond_to?(:size) ? file.size.to_i : 0

      unless Product::IMAGE_CONTENT_TYPES.include?(content_type)
        product.errors.add(:gallery_images, "must be PNG, JPG, WEBP, or GIF")
        return false
      end

      if byte_size > Product::MAX_IMAGE_SIZE
        product.errors.add(:gallery_images, "each image must be smaller than #{Product::MAX_IMAGE_SIZE / 1.megabyte}MB")
        return false
      end
    end

    true
  end
end
