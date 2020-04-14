class ChangeServicePlacesToArray < ActiveRecord::Migration[6.0]
  def up
    change_column :services, :places, :string, array: true, using: "(string_to_array(services.places, ','))"
  end

  def down
    change_column :services, :places, :string, using: "(array_to_string(services.places, ','))", null: true
  end
end
