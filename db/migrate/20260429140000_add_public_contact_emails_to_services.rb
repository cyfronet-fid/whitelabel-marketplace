# frozen_string_literal: true

class AddPublicContactEmailsToServices < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  class MigrationPublicContact < ActiveRecord::Base
    self.table_name = "contacts"
  end

  def up
    add_column :services, :public_contact_emails, :string, array: true, default: [], if_not_exists: true

    MigrationPublicContact
      .where(type: "PublicContact", contactable_type: "Service")
      .group(:contactable_id)
      .pluck(:contactable_id)
      .each do |service_id|
        emails =
          MigrationPublicContact
            .where(type: "PublicContact", contactable_type: "Service", contactable_id: service_id)
            .pluck(:email)
            .compact
            .map(&:strip)
            .reject(&:empty?)
            .uniq

        next if emails.empty?

        execute(<<~SQL.squish)
          UPDATE services
          SET public_contact_emails = #{quote("{#{emails.map { |email| email.gsub(/[{}"]/, "") }.join(",")}}")}
          WHERE id = #{service_id.to_i}
        SQL
      end
  end

  def down
    remove_column :services, :public_contact_emails, if_exists: true
  end
end
