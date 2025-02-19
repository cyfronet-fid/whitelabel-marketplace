# frozen_string_literal: true

class Backoffice::Providers::StepsController < Backoffice::ApplicationController
  include UrlHelper

  class WizardActionError < StandardError
  end

  class CommitValueError < StandardError
  end

  helper_method :back_title, :next_title, :submit_title

  FORM_STEPS = {
    profile: %i[name abbreviation description website logo legal_entity],
    location: %i[street_name_and_number postal_code city region country],
    contacts: [
      main_contact_attributes: %i[id first_name last_name email country_phone_code phone position],
      public_contacts_attributes: %i[id first_name last_name email country_phone_code phone position _destroy]
    ],
    manager: [data_administrators_attributes: %i[id first_name last_name email _destroy]]
  }.freeze

  def show
    validate_wizard_action
    step_state(params[:id].to_sym)
  end

  def update
    set_completion_level if session[:wizard_action] == "create"
    provider_id = session[:provider_id]
    saved_params = session[provider_id]
    provider_attrs = saved_params.merge permitted_step_attributes

    @provider = Provider.new(provider_attrs)
    if @provider.valid?
      session[provider_id] = provider_attrs
      redirect_to_next_step(params[:commit])
    else
      render :show
    end
  end

  private

  def target_step(commit)
    if commit == next_title
      return next_step
    elsif commit == back_title
      return prev_step
    else
      target_step_value = commit.split[-1].downcase.to_sym
      return target_step_value if steps.include? target_step_value
    end
    raise CommitValueError, "Unknown commit value"
  end

  def set_completion_level
    completion_level = [current_step_index, session[:wizard_completion_level]].max
    session[:wizard_completion_level] = completion_level
  end

  def redirect_to_next_step(commit)
    if commit == submit_title
      finish_wizard_path
    else
      target_step_value = target_step(commit)
      step_state(target_step_value.to_sym)
      render turbo_stream:
               turbo_stream.update(
                 "provider-form",
                 partial: partial_path(target_step_value),
                 locals: {
                   provider: @provider
                 }
               )
    end
  end

  def clear_session_data
    session.delete session[:provider_id]
    session.delete(:provider_id)
    session.delete(:wizard_action)
    session.delete(:wizard_completion_level)
  end

  def finish_wizard_path
    provider_id = session[:provider_id]
    saved_params = session[provider_id]
    clear_session_data

    if session[:wizard_action] == "create"
      @provider = Provider.new(permitted_attributes(Provider).merge(saved_params))
      if valid_model_and_urls? && @provider.save(validate: false)
        redirect_to backoffice_provider_path(@provider), notice: "New provider created successfully"
      else
        render :show, status: :unprocessable_entity
      end
    else
      @provider = Provider.find_by(id: provider_id)
      @provider.update!(saved_params)
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
  end

  def set_location
    find_and_authorize
  end

  def set_contacts
    find_and_authorize
    @provider.build_main_contact if @provider.main_contact.blank?
    @provider.public_contacts.build if @provider.public_contacts.empty?
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
    current_step_index < 4 ? steps[current_step_index + 1] : steps[current_step_index]
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
    valid
  end

  def validate_wizard_action
    raise WizardActionError, "wizard_action parameter not set" if session[:wizard_action].nil?
    unless %w[create update].include? session[:wizard_action]
      raise WizardActionError, "Unpermitted wizard_action parameter"
    end
  end

  def find_and_authorize
    provider_id = session[:provider_id]
    session[provider_id] ||= {}
    provider_attrs = session[provider_id] || {}
    @provider = Provider.new provider_attrs
  end

  def next_title
    "Next"
  end

  def back_title
    "Back"
  end

  def submit_title
    "#{session[:wizard_action].capitalize} provider"
  end
end
