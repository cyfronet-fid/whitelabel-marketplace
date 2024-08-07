# frozen_string_literal: true

class BackofficesController < Backoffice::ApplicationController
  def show
    redirect_to backoffice_services_path if current_user&.providers&.size&.positive?
  end
end
