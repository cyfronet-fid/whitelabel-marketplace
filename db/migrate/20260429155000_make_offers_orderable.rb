# frozen_string_literal: true

class MakeOffersOrderable < ActiveRecord::Migration[7.2]
  def up
    add_column :offers, :orderable_type, :string, if_not_exists: true
    add_column :offers, :orderable_id, :bigint, if_not_exists: true

    if column_exists?(:offers, :service_id)
      execute <<~SQL.squish
        UPDATE offers
        SET orderable_type = 'Service',
            orderable_id = service_id
        WHERE service_id IS NOT NULL
          AND orderable_id IS NULL
      SQL

      remove_index :offers, name: "index_offers_on_service_id_and_iid", if_exists: true
      remove_index :offers, name: "index_offers_on_service_id", if_exists: true
      remove_column :offers, :service_id, if_exists: true
    end

    add_index :offers, %i[orderable_type orderable_id], if_not_exists: true
  end

  def down
    add_reference :offers, :service, index: true unless column_exists?(:offers, :service_id)

    execute <<~SQL.squish
      UPDATE offers
      SET service_id = orderable_id
      WHERE orderable_type = 'Service'
        AND service_id IS NULL
    SQL

    add_index :offers, %i[service_id iid], unique: true, if_not_exists: true
    remove_index :offers, name: "index_offers_on_orderable_type_and_orderable_id", if_exists: true
    remove_column :offers, :orderable_type, if_exists: true
    remove_column :offers, :orderable_id, if_exists: true
  end
end
