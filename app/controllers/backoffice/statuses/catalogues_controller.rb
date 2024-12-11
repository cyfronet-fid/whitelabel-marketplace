# frozen_string_literal: true

class Backoffice::Statuses::CataloguesController < Backoffice::CataloguesController
  def create
    @catalogues = Catalogue.where(id: params[:catalogue_ids])
    @catalogues.each do |catalogue|
      next if "Catalogue::#{params[:commit]}".constantize.call(catalogue)
      redirect_to backoffice_catalogues_path,
                  alert:
                    "Catalogue #{catalogue.name} was not #{params[:commit]}ed. " +
                      "Reason: #{catalogue.errors.full_messages.to_sentence}" and return nil
    end
    respond_to do |format|
      notice = "Selected Catalogues are successfully #{params[:commit]}ed."
      format.turbo_stream { flash.now[:notice] = notice }
      format.html { redirect_to backoffice_catalogues_path, notice: notice }
    end
  end
end
