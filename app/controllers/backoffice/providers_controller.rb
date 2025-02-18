# frozen_string_literal: true

class Backoffice::ProvidersController < Backoffice::ApplicationController
  include UrlHelper

  before_action :find_and_authorize, only: %i[show edit update destroy]
  before_action :catalogue_scope
  skip_before_action :backoffice_authorization!, only: %i[index show new create update]

  def index
    authorize(Provider)
    @pagy, @providers = pagy(policy_scope(Provider).order(:name))
  end

  def show
  end

  def new
    provider_builder_key = Random.urlsafe_base64(6)
    session[:provider_id] = provider_builder_key
    session[:wizard_action] = "create"
    session[:wizard_completion_level] = -1
    session[provider_builder_key] = {}
    redirect_to backoffice_provider_step_path(provider_builder_key, "profile")
  end

  def edit
    session[:provider_id] = @provider.id
    session[:wizard_action] = "update"
    session[:wizard_completion_level] = 4
    session[@provider.id] = create_provider_hash(@provider)
    redirect_to backoffice_provider_step_path(@provider, "profile")
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
end
