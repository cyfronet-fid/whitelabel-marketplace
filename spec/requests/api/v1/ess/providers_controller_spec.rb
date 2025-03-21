# frozen_string_literal: true

require "swagger_helper"
require "rails_helper"

RSpec.describe Api::V1::Ess::ProvidersController, swagger_doc: "v1/ess_swagger.json" do
  before(:all) do
    Dir.chdir Rails.root.join("swagger", "v1") # Workaround for rswag bug: https://github.com/rswag/rswag/issues/393
  end

  after(:all) do
    Dir.chdir Rails.root # Workaround for rswag bug: https://github.com/rswag/rswag/issues/393
  end

  path "/api/v1/ess/providers" do
    get "lists providers" do
      tags "providers"
      produces "application/json"
      security [authentication_token: []]

      response 200, "providers found" do
        schema "$ref" => "ess/provider/provider_index.json"

        let!(:manager) { create(:user, roles: [:coordinator]) }
        let!(:providers) { create_list(:provider, 2) }
        let!(:draft) { create(:provider, status: :draft) }
        let!(:deleted) { create(:provider, status: :deleted) }

        let(:"X-User-Token") { manager.authentication_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(providers.size)
          expect(data).to eq(providers&.map { |s| Ess::ProviderSerializer.new(s).as_json.deep_stringify_keys })
        end
      end

      response 403, "user doesn't have manager role", document: false do
        schema "$ref" => "error.json"
        let(:regular_user) { create(:user) }
        let(:manager) { create(:user, roles: [:coordinator]) }
        let(:providers) { create_list(:provider, 3) }

        let(:"X-User-Token") { regular_user.authentication_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq({ error: "You are not authorized to perform this action." }.deep_stringify_keys)
        end
      end

      response 401, "user not recognized" do
        schema "$ref" => "error.json"
        let(:"X-User-Token") { "asdasdasd" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq({ error: "You need to sign in or sign up before continuing." }.deep_stringify_keys)
        end
      end
    end
  end

  path "/api/v1/ess/providers/{provider_id}" do
    parameter name: :provider_id, in: :path, type: :string, description: "Provider identifier (id or pid)"

    get "retrieves a provider by id" do
      tags "providers"
      produces "application/json"
      security [authentication_token: []]

      %i[id pid].each do |id_form|
        response 200, "provider found by #{id_form}" do
          schema "$ref" => "ess/provider/provider_read.json"
          let!(:manager) { create(:user, roles: [:coordinator]) }
          let!(:provider) { create(:provider) }

          let(:provider_id) { provider.send(id_form) }
          let(:"X-User-Token") { manager.authentication_token }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to eq(Ess::ProviderSerializer.new(provider).as_json.deep_stringify_keys)
          end
        end
      end

      response 404, "draft provider not found by id" do
        schema "$ref" => "error.json"
        let!(:manager) { create(:user, roles: [:coordinator]) }
        let!(:provider) { create(:provider, status: :draft) }

        let(:provider_id) { provider.id }
        let(:"X-User-Token") { manager.authentication_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq({ error: "Resource not found" }.deep_stringify_keys)
        end
      end

      response 403, "provider not found by unpermitted user" do
        schema "$ref" => "error.json"
        let!(:regular_user) { create(:user) }
        let!(:provider) { create(:provider, status: :draft) }

        let(:provider_id) { provider.id }
        let(:"X-User-Token") { regular_user.authentication_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq({ error: "You are not authorized to perform this action." }.deep_stringify_keys)
        end
      end

      response 401, "user not recognized" do
        schema "$ref" => "error.json"
        let(:"X-User-Token") { "asdasdasd" }
        let(:provider_id) { "test" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq({ error: "You need to sign in or sign up before continuing." }.deep_stringify_keys)
        end
      end
    end
  end
end
