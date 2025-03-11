# frozen_string_literal: true

module Backoffice::ProvidersHelper
  PROFILE_4_ENABLED = Rails.configuration.profile_4_enabled.freeze
  PROVIDER_TABS = %i[basic marketing classification location contact maturity dependencies other admins].freeze

  def cant_edit(attribute)
    !policy([:backoffice, @provider]).permitted_attributes.include?(attribute)
  end

  def render_step(step_id, provider)
    render "backoffice/providers/steps/#{step_id}", provider: provider, step_index: step_id
  end

  def hosting_legal_entity_input(form)
    if PROFILE_4_ENABLED
      form.input :hosting_legal_entity,
                 collection: Vocabulary.where(type: "Vocabulary::HostingLegalEntity"),
                 disabled: cant_edit(:hosting_legal_entity),
                 label_method: :name,
                 value_method: :id,
                 input_html: {
                   multiple: false,
                   data: {
                     choice: true
                   }
                 }
    else
      form.input :hosting_legal_entity_string,
                 label: "Hosting Legal Entity",
                 disabled: cant_edit(:hosting_legal_entity_string)
    end
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

  def preloaded(provider)
    params[:provider_id] == "new" ? provider : Provider.with_attached_logo.find(params[:provider_id])
  end

  def provider_tabs
    PROVIDER_TABS
  end

  def exit_confirm_details
    summary_step = link_to "summary step", backoffice_provider_step_path(params[:provider_id], "summary"), method: :post
    _("If you leave, you will lose your changes, go to the #{summary_step} and save them")
  end
end
