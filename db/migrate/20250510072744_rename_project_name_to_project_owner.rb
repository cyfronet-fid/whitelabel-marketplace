# frozen_string_literal: true

class RenameProjectNameToProjectOwner < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:projects, :project_owner) || !column_exists?(:projects, :project_name)

    rename_column :projects, :project_name, :project_owner
  end
end
