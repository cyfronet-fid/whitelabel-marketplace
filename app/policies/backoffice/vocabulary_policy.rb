# frozen_string_literal: true

class Backoffice::VocabularyPolicy < Backoffice::ApplicationPolicy
  class Scope < Scope
    def resolve
      scope
    end
  end

  def index?
    service_portfolio_manager?
  end

  def show?
    service_portfolio_manager?
  end

  def permitted_attributes
    %i[name description logo eid parent_id]
  end
end
