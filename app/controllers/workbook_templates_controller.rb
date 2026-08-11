require "zip"

class WorkbookTemplatesController < ApplicationController
  before_action :require_company_template_manager!

  def index
    @workbook_templates = current_user.company.workbook_templates.with_attached_workbook.order(created_at: :desc)
    @workbook_template = current_user.company.workbook_templates.new
  end

  def create
    @workbook_template = current_user.company.workbook_templates.new(template_params)
    @workbook_template.field_mappings = core_mappings
    @workbook_template.item_mapping = item_mapping
    @workbook_template.custom_fields = custom_fields
    @workbook_template.errors.add(:workbook, "is not a valid Excel workbook") unless valid_uploaded_workbook?
    if @workbook_template.errors.empty? && @workbook_template.save
      redirect_to workbook_templates_path, notice: "客户 Excel 模板已保存，可以在报价中选择。"
    else
      @workbook_templates = current_user.company.workbook_templates.with_attached_workbook.order(created_at: :desc)
      flash.now[:alert] = @workbook_template.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    template = current_user.company.workbook_templates.find(params[:id])
    if template.destroy
      redirect_to workbook_templates_path, notice: "模板已删除。"
    else
      redirect_to workbook_templates_path, alert: "这个模板已用于报价，不能删除。"
    end
  end

  private

  def template_params
    params.require(:workbook_template).permit(:name, :workbook)
  end

  def core_mappings
    params.fetch(:core_mappings, {}).permit(*WorkbookTemplate::CORE_FIELDS).to_h.transform_values { |value| value.to_s.upcase.strip }.compact_blank
  end

  def item_mapping
    source = params.fetch(:item_mapping, {}).permit(:sheet, :start_row, *WorkbookTemplate::ITEM_FIELDS)
    columns = WorkbookTemplate::ITEM_FIELDS.index_with { |key| source[key].to_s.upcase.strip }.compact_blank
    { "sheet" => source[:sheet].to_s.strip, "start_row" => source[:start_row].to_i, "columns" => columns }
  end

  def custom_fields
    params.dig(:workbook_template, :custom_fields_text).to_s.lines.filter_map do |line|
      next if line.strip.blank?
      key, label, cell, required, type = line.strip.split("|", 5).map(&:strip)
      { "key" => key.to_s.parameterize(separator: "_"), "label" => label, "cell" => cell.to_s.upcase,
        "required" => required == "required", "type" => type.to_s.presence_in(WorkbookTemplate::CUSTOM_FIELD_TYPES) || "text" }
    end
  end

  def valid_uploaded_workbook?
    upload = params.dig(:workbook_template, :workbook)
    return false unless upload.respond_to?(:tempfile)

    Zip::File.open(upload.tempfile.path) do |zip|
      zip.entries.size <= CustomerWorkbookGenerator::MAX_PACKAGE_ENTRIES &&
        zip.find_entry("xl/workbook.xml").present? && zip.find_entry("[Content_Types].xml").present?
    end
  rescue Zip::Error, Errno::ENOENT
    false
  end
end
