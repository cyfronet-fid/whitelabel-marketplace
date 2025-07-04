# frozen_string_literal: true

module Backoffice::ProvidersHelper
  BASIC_STEPS = %w[profile location contacts managers summary].freeze
  EXTENDED_STEPS = %w[profile classification location contacts maturity dependencies managers other].freeze

  TAB_PARAMS = {
    profile: [
      :name,
      :abbreviation,
      :website,
      :logo,
      :legal_entity,
      :legal_atatus,
      :hosting_legal_entity,
      alternative_identifier_atrributes: %i[identifier_type value]
    ],
    classification: %i[scientific_domain_ids tag_list stucture_type_ids],
    location: %i[street_name_and_number postal_code city region country],
    contacts: [
      main_contact_attributes: %i[id first_name last_name email country_phone_code phone position],
      public_contacts_attributes: %i[id first_name last_name email country_phone_code phone position _destroy]
    ],
    maturity: %i[provider_life_cycle_status certifications],
    dependencies: %i[participating_countries affiliations network_ids catalogue_id],
    managers: [data_administrators_attributes: %i[id first_name last_name email _destroy]],
    other: %i[
      esfri_domain_ids
      esfri_type
      meril_scientific_domain_ids
      area_of_activity_ids
      societal_grand_challenge_ids
      national_roadmaps
    ]
  }.freeze

  def cant_edit(attribute)
    !policy([:backoffice, @provider]).permitted_attributes.include?(attribute)
  end

  def render_step(step, provider, extended_form)
    render partial_path(step, extended_form: extended_form), provider: provider, extended_form: extended_form
  end

  def form_directory(extended_form)
    extended_form ? "form" : "steps"
  end

  def partial_path(step, extended_form: false)
    "backoffice/providers/#{form_directory(extended_form)}/#{step}"
  end

  def next_title
    "Next ->"
  end

  def back_title
    "<- Back"
  end

  def submit_title
    "#{session[:wizard_action].capitalize} provider"
  end

  def preloaded(provider)
    params[:provider_id] == "new" ? provider : Provider.with_attached_logo.find(params[:provider_id])
  end

  def basic_steps
    BASIC_STEPS
  end

  def extended_steps
    EXTENDED_STEPS
  end

  def exit_confirm_details
    summary_step = link_to "summary step", "#", data: { action: "click->form-redirect#goToSummary" }
    _("If you leave, you will lose your changes, go to the #{summary_step} and save them")
  end
end
