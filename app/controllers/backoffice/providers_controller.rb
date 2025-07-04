# frozen_string_literal: true

class Backoffice::ProvidersController < Backoffice::ApplicationController
  include Backoffice::ProvidersHelper
  include UrlHelper
  include ApplicationHelper

  before_action :find_and_authorize, only: %i[show edit update destroy]
  before_action :catalogue_scope
  skip_before_action :backoffice_authorization!, only: %i[index show new create update exit]
  helper_method :current_step_index, :total_steps

  def index
    authorize(Provider)
    @pagy, @providers = pagy(policy_scope(Provider).order(:name))
    @approval_requests = policy_scope(ApprovalRequest.includes(:approvable).active.order(created_at: :desc))
  end

  def show
    @pagy, @services = pagy(@provider.managed_services.order(:name))
    current_tab = params[:tab]
    @tab = current_tab&.in?(extended_steps) ? current_tab : "profile"
  end

  def new
    @provider = Provider.new
    session[:wizard_action] = "create"
    session[:new] ||= {}
    session[:provider_step] = params[:step] || "profile"
    redirect_to backoffice_provider_wizard_path("new")
  end

  def create
    permitted_attributes = permitted_attributes(Provider)
    @provider = Provider.new(**permitted_attributes, status: :unpublished)
    authorize(@provider)

    if valid_model_and_urls? && @provider.save(validate: false)
      if current_user.providers.published.empty? && !current_user.coordinator?
        ar = ApprovalRequest.new(approvable: @provider, user: current_user, status: :published)
        ar.save
      end
      redirect_to backoffice_provider_path(@provider, page: params[:page]), notice: "New provider created successfully"
    else
      catalogue_scope
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    session[:wizard_action] = "update"
    @tab = session[:provider_step] = params[:step] || basic_steps.first
    respond_to do |format|
      if @tab == basic_steps.first
        format.html { redirect_to backoffice_provider_wizard_path(@provider) }
        format.turbo_stream { redirect_to backoffice_provider_wizard_path(@provider) }
      else
        add_missing_nested_models
        format.turbo_stream
        format.html
      end
    end
  end

  def current_step_index
    extended_steps.index(@provider.current_step)
  end

  def total_steps
    extended_steps.size
  end

  def update
    provider_duplicate = @provider.dup

    # IMPORTANT!!! Writing upstream_id from params is required to inject context to policy
    provider_duplicate.upstream_id = params[:provider][:upstream_id]
    permitted_attributes = permitted_attributes(provider_duplicate)
    if provider_duplicate.published? && provider_duplicate.catalogue.present? &&
         !provider_duplicate.catalogue.published?
      attrs.merge(status: provider_duplicate&.catalogue&.status)
    end
    @provider.assign_attributes(permitted_attributes)

    if valid_model_and_urls? && @provider.save(validate: false)
      flash.now[:notice] = "Provider updated successfully"
      respond_to(&:turbo_stream)
    else
      catalogue_scope
      add_missing_nested_models
      @tab = errored_tab(@provider)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    respond_to do |format|
      if Provider::Delete.call(@provider)
        @provider.reload
        notice = "Provider removed successfully"
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to backoffice_providers_path(page: params[:page]), notice: notice }
      else
        alert = "This Provider has services connected to it, therefore is not possible to remove it."
        format.turbo_stream { flash.now[:alert] = alert }
        format.html { redirect_to backoffice_provider_path(@provider), alert: alert }
      end
    end
  end

  def exit
    clear_session_data
    if params[:provider_id] == "new"
      redirect_to backoffice_providers_path, status: :see_other
    else
      @provider = Provider.friendly.find(params[:provider_id])
      redirect_to backoffice_provider_path(@provider), status: :see_other
    end
  end

  private

  def catalogue_scope
    @catalogues = policy_scope(Catalogue.associable).with_attached_logo
  end

  def find_and_authorize
    @provider = Provider.with_attached_logo.friendly.find(params[:id])
    authorize(@provider)
  end

  def add_missing_nested_models
    %i[alternative_identifiers data_administrators public_contacts link_multimedia_urls].each do |association|
      @provider.send(association).build if @provider.send(association).empty?
    end
    @provider.build_main_contact if @provider.main_contact.blank?
  end

  def valid_model_and_urls?
    # More restricted validation in form instead of ActiveRecord itself
    # is related to loose validation of importing data from external services
    valid = @provider.valid?
    if @provider.website_changed? && !UrlHelper.url_valid?(@provider.website)
      valid = false
      @provider.errors.add(:website, "isn't valid or website doesn't exist, please check URL")
    end

    invalid_multimedia =
      @provider.link_multimedia_urls.reject { |media| media.url.blank? || UrlHelper.url_valid?(media.url) }
    if @provider.link_multimedia_urls&.any?(&:changed?) && invalid_multimedia.present?
      valid = false
      @provider.errors.add(
        :link_multimedia_urls,
        "aren't valid or media don't exist, please check URLs: #{invalid_multimedia.map(&:url).join(", ")}"
      )
    end

    if @provider.errors.present? && @provider.errors.to_hash.length == 1 && @provider.errors["sources.eid"].present?
      @provider.errors.clear
      valid = true
    end
    valid
  end

  def errored_tab(provider)
  end

  def clear_session_data
    session.delete(session_key.to_sym)
    session.delete(:wizard_action)
    session.delete(:provider_step)
  end

  def session_key
    @provider.present? ? @provider.id : params[:provider_id]
  end
end
