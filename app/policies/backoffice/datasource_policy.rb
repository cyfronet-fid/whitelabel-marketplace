# frozen_string_literal: true

class Backoffice::DatasourcePolicy < Backoffice::ApplicationPolicy
  class Scope < Scope
    def resolve
      scope
    end
  end

  MP_INTERNAL_FIELDS = [:upstream_id, [sources_attributes: %i[id source_type eid _destroy]]].freeze

  def index?
    coordinator?
  end

  def show?
    coordinator?
  end

  def new?
    coordinator?
  end

  def create?
    coordinator?
  end

  def edit?
    coordinator?
  end

  def update?
    coordinator?
  end

  def destroy?
    coordinator?
  end

  def publish?
    coordinator? && record.draft? && !record.deleted?
  end

  def draft?
    coordinator? && record.published? && !record.deleted?
  end

  def permitted_attributes
    attrs = [
      :name,
      :resource_organisation_id,
      [provider_ids: []],
      :webpage_url,
      :description,
      :logo,
      [scientific_domain_ids: []],
      [category_ids: []],
      [access_type_ids: []],
      [tag_list: []],
      [trl_ids: []],
      [catalogue_ids: []],
      :terms_of_use_url,
      :privacy_policy_url,
      :access_policies_url,
      :order_type,
      :order_url,
      :publishing_date,
      :resource_type,
      [urls: []],
      [public_contact_emails: []],
      :version_control,
      :jurisdiction_id,
      :datasource_classification_id,
      :thematic,
      [research_product_types: []],
      :upstream_id,
      [sources_attributes: %i[id source_type eid _destroy]],
      [alternative_identifiers_attributes: %i[id identifier_type value _destroy]]
    ]

    !@record.is_a?(Provider) || @record.upstream_id.blank? ? attrs : attrs & MP_INTERNAL_FIELDS
  end
end
