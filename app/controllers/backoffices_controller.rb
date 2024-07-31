# frozen_string_literal: true

class BackofficesController < Backoffice::ApplicationController
  def show
    # Uncomment this after rebase on master
    # if current_user.providers.size.positive?
    #   redirect_to backoffice_services_path
    # end
  end
end
