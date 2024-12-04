# frozen_string_literal: true

class BackofficesController < Backoffice::ApplicationController
  def show
    if policy_scope(Provider).size.positive?
      redirect_to backoffice_services_path
    else
      redirect_to backoffice_providers_path
    end
  end
end
