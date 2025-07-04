# frozen_string_literal: true

class Presentable::StatusActionsComponent < ApplicationComponent
  include FormsHelper
  include Turbo::FramesHelper
  def initialize(object:, publish: false, unpublish: false, suspend: false, destroy: false)
    super()
    @object = object
    @object_type = object_type
    @publish = publish
    @unpublish = unpublish
    @suspend = suspend
    @destroy = destroy
  end

  def object_type
    @object.class.name.downcase == "datasource" ? "service" : @object.class.name.downcase
  end

  def suspend_path
    polymorphic_path([:backoffice, @object, :unpublish], suspend: true)
  end

  def unpublish_path
    polymorphic_path([:backoffice, @object, :unpublish])
  end
end
