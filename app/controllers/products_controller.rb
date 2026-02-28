class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :set_primary_image, :remove_primary_image, :remove_gallery_image ]

  def index
    @products = current_user.company.products.order(:name)
    @search_query = params[:query]
    @products = @products.where("name ILIKE ?", "%#{@search_query}%") if @search_query.present?
  end

  def show
    reference_scope = @product.quote_items.joins(:quote).where(quotes: { company_id: current_user.company_id })
    @quote_reference_count = reference_scope.distinct.count("quotes.quote_no")
    @last_referenced_at = reference_scope.maximum("quotes.updated_at")
  end

  def new
    @product = current_user.company.products.new
  end

  def create
    @product = current_user.company.products.new(product_params)

    if @product.save
      attach_uploaded_gallery_images(@product)
      @product.ensure_display_image!
      redirect_to @product, notice: "Product created successfully"
    else
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "already exists in your product list")
    flash.now[:alert] = @product.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    if e.message.to_s.downcase.include?("unique") && e.message.to_s.downcase.include?("sku")
      @product.errors.add(:sku, "already exists in your product list")
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    else
      raise
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      apply_bulk_gallery_deletion(@product)
      attach_uploaded_gallery_images(@product)
      @product.ensure_display_image!
      redirect_to @product, notice: "Product updated successfully"
    else
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @product.errors.add(:sku, "already exists in your product list")
    flash.now[:alert] = @product.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    if e.message.to_s.downcase.include?("unique") && e.message.to_s.downcase.include?("sku")
      @product.errors.add(:sku, "already exists in your product list")
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    else
      raise
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: "Product deleted successfully"
  end

  def set_primary_image
    attachment = @product.gallery_images.attachments.find_by(id: params[:attachment_id])
    return redirect_to edit_product_path(@product), alert: "Image not found" unless attachment

    @product.image.attach(attachment.blob)
    redirect_to edit_product_path(@product), notice: "Display image updated"
  end

  def remove_primary_image
    @product.image.purge_later if @product.image.attached?
    @product.reload
    @product.ensure_display_image!
    redirect_to edit_product_path(@product), notice: "Display image removed"
  end

  def remove_gallery_image
    attachment = @product.gallery_images.attachments.find_by(id: params[:attachment_id])
    return redirect_to edit_product_path(@product), alert: "Image not found" unless attachment

    removing_primary = @product.image.attached? && @product.image.blob_id == attachment.blob_id
    attachment.purge_later
    @product.image.purge_later if removing_primary
    @product.reload
    @product.ensure_display_image!
    redirect_to edit_product_path(@product), notice: "Gallery image removed"
  end

  private

  def set_product
    @product = current_user.company.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :sku, :description, :default_price, :price_currency)
  end

  def remove_gallery_image_ids
    params.fetch(:product, {}).fetch(:remove_gallery_image_ids, []).reject(&:blank?).map(&:to_i)
  end

  def apply_bulk_gallery_deletion(product)
    ids = remove_gallery_image_ids
    return if ids.empty?

    attachments = product.gallery_images.attachments.where(id: ids)
    return if attachments.blank?

    removing_primary = product.image.attached? && attachments.any? { |a| a.blob_id == product.image.blob_id }
    attachments.each(&:purge_later)
    product.image.purge_later if removing_primary
    product.reload
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
end
