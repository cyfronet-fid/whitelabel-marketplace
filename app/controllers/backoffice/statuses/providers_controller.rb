# frozen_string_literal: true

class Backoffice::Statuses::ProvidersController < Backoffice::ProvidersController
  def create
    @providers = Provider.where(id: params[:provider_ids])
    @providers.each do |provider|
      next if "Provider::#{params[:commit]}".constantize.call(provider)
      redirect_to backoffice_statuses_providers_path,
                  alert:
                    "Provider #{provider.name} was not #{params[:commit]}ed. " +
                      "Reason: #{provider.errors.full_messages.to_sentence}"
    end
    redirect_to backoffice_statuses_providers_path, notice: "Selected Providers are successfully #{params[:commit]}ed."
  end
end
