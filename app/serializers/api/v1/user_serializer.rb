# frozen_string_literal: true

class Api::V1::UserSerializer < ActiveModel::Serializer
  attributes :uid, :roles

  def roles
    object.roles.map(&:name)
  end
end
