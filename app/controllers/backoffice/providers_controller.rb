# frozen_string_literal: true

class Backoffice::ProvidersController < Backoffice::ApplicationController
  include Backoffice::ProvidersHelper
  include UrlHelper

  before_action :find_and_authorize, only: %i[show edit update destroy]
  before_action :catalogue_scope
  skip_before_action :backoffice_authorization!, only: %i[index show new create update]

  def index
    authorize(Provider)
    @pagy, @providers = pagy(policy_scope(Provider).order(:name))
    @approval_requests = policy_scope(ApprovalRequest.includes(:approvable).active.order(created_at: :desc))
  end

  def show
    respond_to do |format|
      current_tab = params[:tab]
      partial = current_tab.present? && current_tab.to_sym.in?(provider_tabs) ? params[:tab].to_sym : :basic
      format.turbo_stream do
        render turbo_stream:
                 turbo_stream.replace(
                   "tab_content",
                   partial: "backoffice/providers/tabs/wrapper",
                   locals: {
                     tab: partial,
                     provider: @provider
                   }
                 )
      end
      format.html
    end
  end

  def new
    @provider = Provider.new
    session[:wizard_action] = "create"
    session[:new] = {}
    redirect_to backoffice_provider_step_path("new", "profile")
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
    add_missing_nested_models
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
      redirect_to backoffice_provider_path(@provider), notice: "Provider updated successfully"
    else
      if @provider.public_contacts.present? && @provider.public_contacts.all?(&:marked_for_destruction?)
        @provider.public_contacts[0].reload
      end
      if @provider.data_administrators.present? && @provider.data_administrators.all?(&:marked_for_destruction?)
        @provider.data_administrators[0].reload
      end
      catalogue_scope
      add_missing_nested_models
      render :edit, status: :bad_request
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
    redirect_to backoffice_providers_path
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
      @provider.link_multimedia_urls.reject { |media| media.url.blank? ? true : UrlHelper.url_valid?(media.url) }
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

  def create_provider_hash(provider)
    to_except = %i[id created_at updated_at]
    contact_except = to_except + %i[contactable_type contactable_id]

    data_administrators_attributes =
      provider.data_administrators.map.with_index { |dm, i| { i.to_s => dm.as_json(except: to_except) } }
    public_contacts_attributes =
      provider.public_contacts.map.with_index { |pc, i| { i.to_s => pc.as_json(except: contact_except) } }

    provider_hash = provider.as_json(except: to_except)
    provider_hash["country"] = provider_hash["country"]["country_data_or_code"]
    if @provider.main_contact
      provider_hash["main_contact_attributes"] = @provider.main_contact.as_json(except: contact_except)
    end

    provider_hash["public_contacts_attributes"] = public_contacts_attributes.reduce({}, :merge)
    provider_hash["data_administrators_attributes"] = data_administrators_attributes.reduce({}, :merge)
    provider_hash
  end

  def session_key
    @provider.present? ? @provider&.id.to_s : params[:provider_id]
  end

  def clear_session_data
    session.delete(session_key.to_sym)
    session.delete(:wizard_action)
  end
end
