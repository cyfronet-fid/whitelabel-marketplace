# frozen_string_literal: true

class StripProviderToV6 < ActiveRecord::Migration[7.2]
  REMOVED_COLUMNS = %i[
    street_name_and_number
    postal_code
    city
    region
    tagline
    certifications
    hosting_legal_entity_string
    participating_countries
    affiliations
    national_roadmaps
  ].freeze

  def up
    execute "DELETE FROM taggings WHERE taggable_type = 'Provider'"
    execute "DELETE FROM provider_scientific_domains"
    execute "DELETE FROM contacts WHERE contactable_type = 'Provider' AND type IN ('MainContact', 'PublicContact')"

    REMOVED_COLUMNS.each { |column| remove_column :providers, column, if_exists: true }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
