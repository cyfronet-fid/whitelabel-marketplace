# frozen_string_literal: true

FactoryBot.define do
  factory :offer do
    sequence(:name) { |n| "offer #{n}" }
    sequence(:description) { |n| "offer #{n} description" }
    sequence(:service) { |n| create(:service, offers_count: 1) }
    sequence(:status) { :published }
    sequence(:webpage) { |n| "http://webpage#{n}.invalid" }
    sequence(:offer_type) { :orderable }
    factory :offer_with_parameters do
      sequence(:parameters) { [{ "id": "id1",
                                "type": "input",
                                "label": "Test input",
                                "value_type": "string",
                                "description": "Write sth"
                              }] }
    end
    after :build do |offer|
      offer.offer_type = offer.service.service_type || service.service_type
    end
  end
end
