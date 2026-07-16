class ProformaInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_pi, only: %i[show deposit_received pdf]

  def create
    acceptance = current_user.company.quote_acceptances.find(params.require(:quote_acceptance_id))
    pi = ProformaInvoiceGenerator.new(acceptance: acceptance, actor: current_user).call
    redirect_to proforma_invoice_path(pi)
  end

  def show; end

  def deposit_received
    @pi.update!(status: "deposit_received", deposit_received_at: Time.current)
    @pi.quote.update!(status: "won", won_at: Time.current)
    redirect_to @pi, notice: "Deposit received. Deal marked won."
  end

  def pdf
    html = render_to_string(template: "proforma_invoices/pdf", layout: "pdf", formats: [:html])
    binary = ChromiumPdfRenderer.new(html).render
    send_data binary, filename: "#{@pi.number}.pdf", type: "application/pdf", disposition: "attachment"
  end

  private

  def load_pi
    @pi = current_user.company.proforma_invoices.find(params[:id])
  end
end
