# frozen_string_literal: true

namespace :viewable do
  task update_popularity_ratio: :environment do
    puts "Service popularity ratio update"
    analytics = Google::Analytics.new
    total_views = Analytics::TotalServicesViews.new(analytics).call("services").totals.first.values.first.to_d
    total_project_items = ProjectItem.all.empty? ? 1 : ProjectItem.all.size
    Service.find_each do |service|
      path = "/services/#{service.slug}"
      views = Analytics::PageViewsAndRedirects.new(analytics).call(path)[:views].to_d
      project_items = service.project_items_count.to_d
      service.popularity_ratio = 1000 * ((views / total_views) + (project_items / total_project_items))
      puts "#{service.name}: #{service.popularity_ratio}"
      service.save!
    end
  end

  task :cache_views_count, [:log_level] => :environment do |_t, opts|
    Rails.logger = Logger.new("#{Rails.root}/log/cache_views_count.log")
    logger = Logger.new($stdout)
    Rails.logger.level = Rails.env.production? ? :info : opts[:log_level]&.to_sym || :debug
    logger.info "Update presentable views cache"
    collections = [Service, Bundle, Provider].freeze
    collections.each do |collection|
      collection.find_each do |object|
        logger.info "Calling update of #{object.name} " + "(#{object.id_construct}) #{object.class.name} cache"
        previous = object.usage_counts_views
        object.store_analytics
        logger.info "Successfully updated #{object} #{object.name} with" +
                      " usage_counts_views: #{previous} => #{object.usage_counts_views}"
      end
    end
    logger.info "Heal project_items_counters"
    project_item_counters_collections = [Service, Offer, Bundle].freeze
    project_item_counters_collections.each do |collection|
      collection
        .includes(:project_items)
        .find_each do |object|
          previous = object.project_items_count
          object.update_columns(project_items_count: object.project_items.size)
          logger.info "Update #{object.name} #{object.class} (#{object.id}) " +
                        "#{previous} => #{object.project_items_count}"
        end
    end
    Rails.logger = logger
  end
end
