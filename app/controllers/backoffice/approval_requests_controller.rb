# frozen_string_literal: true

class Backoffice::ApprovalRequestsController < Backoffice::ApplicationController
  before_action :find_and_authorize, only: %i[show update]

  def index
    list_approvals
  end

  def edit
  end

  def show
  end

  def update
    current_action = params[:approval_request][:current_action]
    p "EEEEEE #{params[:approval_request][:current_action]}"
    @approval_request.assign_attributes(
      permitted_attributes(ApprovalRequest).merge(
        status: current_action == "requested_for_changes" || current_action.blank? ? :published : :deleted,
        last_action: current_action
      )
    )
    @approval_request.save
    @message =
      Message.new(
        message: params[:approval_request][:message],
        author: current_user,
        author_role: :mediator,
        scope: :user_direct,
        messageable: @approval_request
      )
    provider = @approval_request.approvable
    case current_action
    when "accepted"
      Provider::Publish.call(provider)
    when "rejected"
      Provider::Delete.call(provider)
    else
      Provider::Unpublish.call(provider)
    end
    list_approvals
    respond_to do |format|
      puts "RRRRRRRRRRRR #{@approval_request.valid?} #{@approval_request.errors.messages}"
      if @approval_request.valid? && Message::Create.new(@message).call
        notice = _("Message sent successfully")
        format.turbo_stream { flash.now[:notice] = notice }
        format.html { redirect_to backoffice_providers_path(notice: notice) }
      else
        alert = _("Message not sent")
        flash.now[:alert] = alert
        format.json { render :edit, status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity, alert: alert }
      end
    end
  end

  private

  def find_and_authorize
    @approval_request = ApprovalRequest.includes(:messages).find(params[:id])
  end

  def list_approvals
    @approval_requests = ApprovalRequest.active.order(created_at: :desc)
  end
end
