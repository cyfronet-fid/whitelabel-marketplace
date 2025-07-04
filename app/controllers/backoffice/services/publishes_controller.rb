# frozen_string_literal: true

class Backoffice::Services::PublishesController < Backoffice::ApplicationController
  before_action :find_and_authorize

  def create
    respond_to do |format|
      if Service::Publish.call(@service)
        type = :notice
        msg = _("Service published successfully")
      else
        type = :alert
        msg = "Service not published. Reason: #{@service.errors.full_messages.join(", ")}"
      end
      flash.now[type] = msg
      format.turbo_stream
      format.html { redirect_to backoffice_service_offers_path(@service) }
    end
  end

  private

  def find_and_authorize
    @service = Service.friendly.find(params[:service_id])
    authorize(@service, :publish?)
  end
end
