# frozen_string_literal: true

class Backoffice::Statuses::ProvidersController < Backoffice::ProvidersController
  before_action :action_type

  def create
    @providers = Provider.where(id: params[:provider_ids])
    respond_to do |format|
      if @providers.each { |p| "Provider::#{@action}".constantize.call(p) }
        notice = "Selected providers was successfully #{@action}ed."
        format.html { redirect_to providers_path(notice: notice) }
        format.turbo_stream { flash.now[:notice] = notice }
      else
        format.html { render :index, status: :unprocessable_entity }
        format.json { render :index, status: :unprocessable_entity }
      end
    end
  end

  def action_type
    @action = params[:status_change] || "Publish"
  end
end
