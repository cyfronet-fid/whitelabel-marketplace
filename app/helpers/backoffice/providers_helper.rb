# frozen_string_literal: true

module Backoffice::ProvidersHelper
  PROFILE_4_ENABLED = Rails.configuration.profile_4_enabled.freeze

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
end
