# frozen_string_literal: true

class Backoffice::ServicePolicy < Backoffice::ApplicationPolicy
  def new?
    management_role?
  end

  def create?
    management_role?
  end

  def preview?
    access?
  end

  def permitted_attributes
    [
      :type,
      :name,
      :description,
      :order_type,
      :node_ids,
      [provider_ids: []],
      :terms_of_use_url,
      :access_policies_url,
      :webpage_url,
      :privacy_policy_url,
      :order_url,
      [access_type_ids: []],
      :logo,
      [trl_ids: []],
      [scientific_domain_ids: []],
      :tag_list,
      [category_ids: []],
      [pc_category_ids: []],
      :catalogue,
      :catalogue_id,
      :status,
      :upstream_id,
      :resource_organisation_id,
      :publishing_date,
      :resource_type,
      [urls: []],
      [public_contact_emails: []],
      :version_control,
      :jurisdiction_id,
      :datasource_classification_id,
      :thematic,
      [research_product_types: []],
      [sources_attributes: %i[id source_type eid _destroy]],
      [alternative_identifiers_attributes: %i[id identifier_type value _destroy]]
    ]
  end

  private

  def project_items
    ProjectItem.joins(:offer).where(offers: { orderable_type: "Service", orderable_id: record.id })
  end
end
