# frozen_string_literal: true

class RemoveServiceOwners < ActiveRecord::Migration[7.1]
  def change
    drop_table :service_user_relationships, if_exists: true
    remove_column :users, :owned_services_count, if_exists: true
  end
end
