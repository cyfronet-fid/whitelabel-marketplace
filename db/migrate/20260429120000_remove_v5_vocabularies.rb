# frozen_string_literal: true

class RemoveV5Vocabularies < ActiveRecord::Migration[7.2]
  def up
    # V5 vocabulary models and lookup tables still back bundles, projects,
    # filters, and vocabulary-management screens in this fork. The V6 profile
    # migration removes them from provider/service/datasource surfaces only.
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
