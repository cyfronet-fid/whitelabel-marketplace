# frozen_string_literal: true

class Presentable::ListComponent < ApplicationComponent
  include Pagy::Frontend
  def initialize(collection:, pagy:)
    super()
    @collection = collection
    @pagy = pagy
    @klass = collection.klass.name.downcase
  end
end
