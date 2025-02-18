# frozen_string_literal: true

module Backoffice::ProvidersHelper
  PROFILE_4_ENABLED = Rails.configuration.profile_4_enabled.freeze

  def cant_edit(attribute)
    !policy([:backoffice, @provider]).permitted_attributes.include?(attribute)
  end

  def get_dialling_code(country)
    Country.get_country_phone_code(country)
  end

  def render_next_step(step_id, provider)
    render "backoffice/providers/steps/#{step_id}", provider: provider
  end

  def completion_level
    session[:wizard_completion_level] + 2
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
end
