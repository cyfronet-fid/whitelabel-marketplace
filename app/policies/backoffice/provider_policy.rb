# frozen_string_literal: true

class Backoffice::ProviderPolicy < Backoffice::ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def new?
    user.present?
  end

  def create?
    user.present?
  end

  def edit?
    edit_permissions?
  end

  def update?
    edit_permissions?
  end

  def exit?
    user.present?
  end

  def permitted_attributes
    [
      :current_step,
      :name,
      :abbreviation,
      :website,
      :status,
      :legal_entity,
      :hosting_legal_entity,
      :node_ids,
      [node_ids: []],
      [legal_status_ids: []],
      :legal_status,
      :description,
      :logo,
      [multimedia: []],
      :country,
      :catalogue,
      :catalogue_id,
      :upstream_id,
      [sources_attributes: %i[id source_type eid _destroy]],
      [public_contact_emails: []],
      [data_administrators_attributes: %i[id first_name last_name email _destroy]],
      [link_multimedia_urls_attributes: %i[id name url _destroy]],
      [alternative_identifiers_attributes: %i[id identifier_type value _destroy]]
    ]
  end

  private

  def catalogue_access?
    user&.catalogue_owner?
  end

  def edit_permissions?
    !record.deleted? && (coordinator? || record&.owned_by?(user))
  end

  def access?
    coordinator? || (record&.owned_by?(user) && record&.approval_requests&.none?(&:published?))
  end
end
