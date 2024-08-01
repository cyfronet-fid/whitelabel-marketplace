# frozen_string_literal: true

class Backoffice::CategoryPolicy < Backoffice::VocabularyPolicy
  def index?
    service_portfolio_manager?
  end

  def show?
    service_portfolio_manager?
  end

  def new?
    service_portfolio_manager?
  end

  def create?
    service_portfolio_manager?
  end

  def update?
    service_portfolio_manager?
  end

  def destroy?
    service_portfolio_manager?
  end

  def permitted_attributes
    %i[name description eid parent_id logo]
  end
end
