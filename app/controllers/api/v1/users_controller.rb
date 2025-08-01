# frozen_string_literal: true

class Api::V1::UsersController < Api::V1::ApplicationController
  def show
    @user = User.find_by!(uid: params[:id])

    render json: Api::V1::UserSerializer.new(@user).as_json, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end
end
