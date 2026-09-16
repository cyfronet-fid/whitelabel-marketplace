# frozen_string_literal: true

class ImportAllJob < ApplicationJob
  queue_as :imports

  # New invoke every 3 minutes, so retry must be low
  sidekiq_options retry: 2

  def perform
    Rails.application.load_tasks
    Rake::Task["import:all"].invoke
  end
end