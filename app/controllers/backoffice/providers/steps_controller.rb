# frozen_string_literal: true

class Backoffice::Providers::StepsController < Backoffice::ApplicationController
  include Backoffice::ProvidersHelper
  include UrlHelper

    class WizardActionError < StandardError
    end

  FORM_STEPS = {
    profile: [
      :name,
      :abbreviation,
      :description,
      :website,
      :logo,
      :legal_entity
    ],
    location: [
        :street_name_and_number,
        :postal_code,
        :city,
        :region, 
        :country
 
    ],
    contacts: [
      main_contact_attributes: %i[id first_name last_name email country_phone_code phone position],
      public_contacts_attributes: %i[id first_name last_name email country_phone_code phone position _destroy]
    ],
    manager: [data_administrators_attributes: %i[first_name last_name email]]
  }.freeze 


  def show
    step_state(params[:id].to_sym)
  end

  def update
    set_completion_level
    provider_id = session[:provider_id]
    saved_params = session[provider_id]

    if params[:commit] ==  back_title
      redirect_to_step(prev_step)
      return
    end

    provider_attrs = saved_params.merge permitted_step_attributes
    @provider = Provider.new(provider_attrs)
    
    if @provider.valid?
      session[provider_id] = provider_attrs
      redirect_to_next_step
    else
      render :show
    end
  end

  private

  def set_completion_level
    completion_level =  [current_step_index, session[:wizard_completion_level]].max
    session[:wizard_completion_level] = completion_level
  end
  
  def redirect_to_step(val)
    provider_id = session[:provider_id]
    @provider = Provider.new(session[provider_id])
    render turbo_stream: turbo_stream.update("provider-form",
            partial: partial_path(val), locals: { provider: @provider })

  end

  def redirect_to_next_step
    if current_step_index == 4
      finish_wizard_path
    else
      target_step = next_step
      step_state(target_step)
      render turbo_stream:
        turbo_stream.update(
            "provider-form",
            partial: partial_path(target_step),
            locals: { provider: @provider })
    end
  end

  def finish_wizard_path
    provider_id = session[:provider_id]
    saved_params = session[provider_id]
    session.delete provider_id
    
    if session[:wizard_action] == "create"
      @provider = Provider.new(permitted_attributes(Provider).merge(saved_params))
      if valid_model_and_urls? && @provider.save(validate: false)
        redirect_to backoffice_provider_path(@provider), notice: "New provider created successfully"
      else
        render :show, status: :unprocessable_entity
      end
    else
      Provider.find_by(id: provider_id).update!(saved_params)
      redirect_to backoffice_provider_path(@provider), notice: "Provider updated successfully"
    end
  end

  def partial_path(step)
    "backoffice/providers/steps/#{step}"
  end

  def step_state(step_to_set)
    method("set_#{step_to_set}").call
  end

  def set_profile
    find_and_authorize
    # provider_id = session[:provider_id]
    # raise WizardActionError, "wizard_action parameter not set" if session[:wizard_action].nil?
    

    # session[provider_id] ||= {}
    # provider_attrs = session[provider_id] || {}
    # @provider = Provider.new provider_attrs
    
    # elsif session[:wizard_action] == "update"
    #   @raid_project = RaidProject.find_by(id: raid_id)
    #   @raid_project.build_main_description if @raid_project.main_description.blank?
    # else
    #   raise WizardActionError, "Unpermitted wizard_action parameter: #{session[:wizard_action]}"
    # end
  end

  def set_location
    find_and_authorize
  end

  def set_contacts
    find_and_authorize
    if @provider.main_contact.blank?
        @provider.build_main_contact
    end
    if @provider.public_contacts.empty?
        @provider.public_contacts.build
    end
  end

  def set_manager
    find_and_authorize
    if @provider.data_administrators.blank?
      @provider.data_administrators << DataAdministrator.new(
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        email: current_user.email
        )
    end
  end

  def set_summary
    find_and_authorize
  end

  def steps
    %i[profile location contacts manager summary]
  end

  def step
    params[:provider] ? params[:provider][:form_step].to_sym : :profile
  end

  def current_step_index
    steps.index(step.to_sym)
  end  

  def next_step
    steps[current_step_index + 1].to_s if current_step_index < 4
  end

  def prev_step
    current_step_index.positive? ? steps[current_step_index - 1] : steps[current_step_index]  
  end

  def permitted_step_attributes
    params.require(:provider).permit(:form_step, *FORM_STEPS[step.to_sym])
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

  def find_and_authorize
    if session[:wizard_action] == "create"
      find_and_authorize_create_mode
    end
  end


  def find_and_authorize_create_mode
    provider_id = session[:provider_id]
    session[provider_id] ||= {}
    provider_attrs = session[provider_id] || {}
    @provider = Provider.new provider_attrs
  end

end
