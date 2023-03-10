# frozen_string_literal: true

module SearchLinksHelper
  EXTERNAL_SEARCH_ENABLED = Rails.configuration.enable_external_search

  def external_search_enabled
    EXTERNAL_SEARCH_ENABLED
  end

  def services_tag_link(tag)
    search_base_url = Mp::Application.config.search_service_base_url
    enable_external_search = Mp::Application.config.enable_external_search
    return search_base_url + "/search/all?q=*&fq=tag_list:%22#{tag}%22" if enable_external_search
    services_path(tag: tag)
  end

  def project_add_link(project)
    search_base_url = Mp::Application.config.search_service_base_url
    enable_external_search = Mp::Application.config.enable_external_search
    return search_base_url + "/search/service?q=*" if enable_external_search
    project_add_path(project)
  end

  def project_add_external_link
    search_base_url = Mp::Application.config.search_service_base_url
    search_base_url + "/search/service?q=*"
  end

  def resource_organisation(service, highlights = nil, preview: false)
    target = service.resource_organisation
    preview_options = preview ? { "data-target": "preview.link" } : {}
    link_to_unless(
      target.deleted? || target.draft?,
      highlighted_for(:resource_organisation_name, service, highlights),
      service.organisation_search_link(target.name),
      preview_options
    )
  end

  def providers(service, highlights = nil, preview: false)
    highlighted = highlights.present? ? sanitize(highlights[:provider_names])&.to_str : ""
    preview_options = preview ? { "data-target": "preview.link" } : {}
    service
      .providers
      .reject(&:blank?)
      .reject(&:deleted?)
      .reject { |p| p == service.resource_organisation }
      .uniq
      .map do |target|
        if highlighted.present? && highlighted.strip == target.name.strip
          link_to_unless target.deleted? || target.draft?,
                         highlights[:provider_names].html_safe,
                         target.provider_search_link,
                         preview_options
        else
          link_to_unless target.deleted? || target.draft?,
                         target.name,
                         service.provider_search_link(target.name),
                         preview_options
        end
      end
  end

  def services_geographical_availabilities_link(service, gcap)
    service.geographical_availabilities_link(gcap)
  end

  def service_resource_organisation(project_item)
    organisation = project_item.service.resource_organisation
    path = project_item.service.organisation_search_link(organisation.name, services_path(providers: organisation.id))
    link_to organisation.name, path
  end

  def service_providers_list(project_item)
    organisation = project_item.service.resource_organisation
    service = project_item.service
    providers =
      project_item
        .service
        .providers
        .reject { |p| p == organisation }
        .map { |p| link_to(p.name, service.provider_search_link(p.name, services_path(providers: p.id))) }
    safe_join(providers, ", ")
  end

  def services_comparison_link(query_params)
    search_base_url = Mp::Application.config.search_service_base_url
    enable_external_search = Mp::Application.config.enable_external_search
    return search_base_url + "/search/service?q=*" if enable_external_search
    services_path(params: query_params)
  end
end