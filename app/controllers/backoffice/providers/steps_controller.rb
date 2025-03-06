# frozen_string_literal: true

class Backoffice::Providers::StepsController < Backoffice::ApplicationController
  include Backoffice::ProvidersHelper
  include UrlHelper
  skip_before_action :backoffice_authorization!
  before_action :validate_wizard_action, only: :show

  helper_method :current_step_index

  class WizardActionError < StandardError
  end

  class CommitValueError < StandardError
  end

  FORM_STEPS = {
    profile: %i[name abbreviation description website logo legal_entity],
    location: %i[street_name_and_number postal_code city region country],
    contacts: [
      main_contact_attributes: %i[id first_name last_name email country_phone_code phone position],
      public_contacts_attributes: %i[id first_name last_name email country_phone_code phone position _destroy]
    ],
    manager: [data_administrators_attributes: %i[id first_name last_name email _destroy]]
  }.freeze

  STEPS = %i[profile location contacts manager summary].freeze

  def show
    prepare_step(params[:id].to_sym)
  end

  def update
    provider_id = params[:provider_id]
    saved_params = session[provider_id]
    provider_attrs = saved_params.merge permitted_step_attributes

    @provider = Provider.new(provider_attrs.except("logo"))
    if @provider.valid?
      @logo =
        if provider_attrs["logo"].present?
          if provider_attrs["logo"].is_a?(Hash)
            provider_attrs["logo"]
          else
            ImageHelper.to_json(provider_attrs.delete("logo"))
          end
        end

      provider_attrs["logo"] = @logo if @logo.present?
      session[provider_id] = provider_attrs
      redirect_to_next_step(params[:commit])
    else
      render :show
    end
  end

  private

  def target_step(commit)
    raise CommitValueError, "Unknown commit value" if commit.blank?

    case commit
    when next_title
      next_step
    when back_title
      prev_step
    else
      target_step_value = commit.split.last&.downcase&.to_sym
      STEPS.include?(target_step_value) ? target_step_value : (raise CommitValueError, "Unknown commit value")
    end
  end

  def redirect_to_next_step(commit)
    if commit == submit_title
      finish_wizard_path
    else
      @step = target_step(commit)
      prepare_step(@step.to_sym)
      render turbo_stream:
               turbo_stream.update(
                 "provider-form",
                 partial: partial_path(@step),
                 locals: {
                   provider: @provider,
                   logo: @logo
                 }
               )
    end
  end

  def clear_session_data
    session.delete(:provider_id)
    session.delete(:wizard_action)
    session.delete(:wizard_completion_level)
  end

  def finish_wizard_path
    saved_params = session[params[:provider_id]]
    @logo = saved_params.delete("logo")
    if params[:provider_id] == "new"
      @provider.status = :unpublished
      if @provider.save
        if current_user.providers.published.empty? && !current_user.coordinator?
          ar = ApprovalRequest.new(approvable: @provider, user: current_user, status: :published)
          ar.save
        end
      else
        render :show, status: :unprocessable_entity
      end
    else
      @provider = Provider.find_by(id: params[:provider_id])
      render :show, status: :unprocessable_entity unless @provider.update(saved_params)
    end
    @provider.update_logo!(@logo) if @logo.present?
    action = session.delete(:wizard_action)
    clear_session_data
    redirect_to backoffice_provider_path(@provider), notice: "Provider #{action}d successfully"
  end

  def partial_path(step)
    "backoffice/providers/steps/#{step}"
  end

  def prepare_step(step_to_set)
    find_and_authorize
    case step_to_set
    when :contacts
      @provider.build_main_contact if @provider.main_contact.blank?
      @provider.public_contacts.build if @provider.public_contacts.empty?
    when :manager
      if @provider.data_administrators.blank?
        @provider.data_administrators << DataAdministrator.new(
          first_name: current_user.first_name,
          last_name: current_user.last_name,
          email: current_user.email
        )
      end
    when :summary
      @logo = session[params[:provider_id]]["logo"]
    end
  end

  def step
    @step ||= params[:id]
  end

  def current_step_index
    STEPS.index(step.to_sym)
  end

  def next_step
    STEPS[[(current_step_index + 1), 5].min]
  end

  def prev_step
    STEPS[[(current_step_index - 1), 0].max]
  end

  def permitted_step_attributes
    params.require(:provider).permit(:form_step, *FORM_STEPS[step.to_sym])
  end

  def validate_wizard_action
    if session[:wizard_action].nil? || !%w[create update].include?(session[:wizard_action])
      raise WizardActionError, "wizard_action parameter not set"
    end
  end

  def find_and_authorize
    provider_id = params[:provider_id]
    session[provider_id] ||= {}
    provider_attrs = session[provider_id]
    @provider = Provider.new provider_attrs.except("logo")
  end
end
