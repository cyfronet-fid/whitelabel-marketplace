# frozen_string_literal: true

class Services::OffersController < ApplicationController
  include Service::Searchable
  include Service::Categorable
  include Service::Autocomplete
  include Service::Comparison
  include Service::Monitorable
  include Service::Recommendable

  def index
    @service = Service.includes(:offers).friendly.find(params[:service_id])
    @service.store_analytics
    @service.monitoring_status = fetch_status(@service.pid)

    authorize(
      ServiceContext.new(@service, params.key?(:from) && params[:from] == "backoffice_service"),
      :show?,
      policy_class: ServiceContextPolicy
    )
    @offers = policy_scope(@service.offers.inclusive).order(:iid)
    @bundles = policy_scope(@service.bundles.published).order(:iid)
    @bundled = bundled
    @similar_services = fetch_similar(@service.id, current_user&.id)
    @related_services = @service.related_services

    @service_opinions = ServiceOpinion.joins(project_item: :offer).where(offers: { service_id: @service })
    @question = Service::Question.new(service: @service)
    @favourite_services =
      current_user&.favourite_services || Service.where(slug: Array(cookies[:favourites]&.split("&") || []))
  end
end
