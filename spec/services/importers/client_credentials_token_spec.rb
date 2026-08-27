# frozen_string_literal: true

require "rails_helper"

describe Importers::ClientCredentialsToken, backend: true do
  subject(:token_importer) { described_class.new }

  let(:client_id) { "import-client" }
  let(:client_secret) { "import-secret" }
  let(:issuer) { "https://checkin.example/realms/core" }
  let(:token_endpoint) { "https://checkin.example/realms/core/protocol/openid-connect/token" }
  let(:discovery) { true }
  let(:client_options) do
    {
      scheme: "https",
      host: "checkin.example",
      port: nil,
      token_endpoint: "/realms/core/protocol/openid-connect/token"
    }
  end

  let(:oidc_config) do
    instance_double(OpenIDConnect::Discovery::Provider::Config::Response, token_endpoint: token_endpoint)
  end

  before do
    allow(ENV).to receive(:fetch).with("IMPORT_CLIENT_ID").and_return(client_id)
    allow(ENV).to receive(:fetch).with("IMPORT_CLIENT_SECRET").and_return(client_secret)

    allow(Devise.omniauth_configs[:checkin]).to receive(:options).and_return(
      discovery: discovery,
      issuer: issuer,
      client_options: client_options
    )

    allow(OpenIDConnect::Discovery::Provider::Config).to receive(:discover!).with(issuer).and_return(oidc_config)
  end

  context "when the token request succeeds" do
    before do
      stub_request(:post, token_endpoint).with(
        body: {
          grant_type: "client_credentials",
          client_id: client_id,
          client_secret: client_secret
        },
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded"
        }
      ).to_return(status: 200, body: { access_token: "received-token" }.to_json)
    end

    it "returns the access token" do
      expect(token_importer.receive_token).to eq("received-token")
    end
  end

  context "when the checkin omniauth discovery config resolves a different token endpoint" do
    let(:token_endpoint) { "https://example.com/token" }

    before do
      stub_request(:post, token_endpoint).to_return(status: 200, body: { access_token: "received-token" }.to_json)
    end

    it "requests the token from the discovered endpoint" do
      expect(token_importer.receive_token).to eq("received-token")
    end
  end

  context "when discovery is disabled" do
    let(:discovery) { false }

    before do
      expect(OpenIDConnect::Discovery::Provider::Config).not_to receive(:discover!)
      stub_request(:post, token_endpoint).to_return(status: 200, body: { access_token: "received-token" }.to_json)
    end

    it "requests the token from the configured client_options endpoint" do
      expect(token_importer.receive_token).to eq("received-token")
    end
  end

  context "when IMPORT_CLIENT_ID is missing" do
    before { allow(ENV).to receive(:fetch).with("IMPORT_CLIENT_ID").and_raise(KeyError) }

    it "raises a key error" do
      expect { token_importer.receive_token }.to raise_error(KeyError)
    end
  end

  context "when IMPORT_CLIENT_SECRET is missing" do
    before { allow(ENV).to receive(:fetch).with("IMPORT_CLIENT_SECRET").and_raise(KeyError) }

    it "raises a key error" do
      expect { token_importer.receive_token }.to raise_error(KeyError)
    end
  end

  context "when the response does not include an access token" do
    before { stub_request(:post, token_endpoint).to_return(status: 200, body: { token_type: "Bearer" }.to_json) }

    it "raises a request error" do
      expect { token_importer.receive_token }.to raise_error(
        described_class::RequestError,
        "Access token response does not include access_token"
      )
    end
  end

  context "when the response is empty" do
    before { stub_request(:post, token_endpoint).to_return(status: 200, body: "") }

    it "raises a request error" do
      expect { token_importer.receive_token }.to raise_error(
        described_class::RequestError,
        "Access token response is empty"
      )
    end
  end

  context "when the response is not valid JSON" do
    before { stub_request(:post, token_endpoint).to_return(status: 200, body: "not-json") }

    it "raises a request error" do
      expect { token_importer.receive_token }.to raise_error(
        described_class::RequestError,
        "Access token response is not valid JSON"
      )
    end
  end

  context "when the request fails" do
    before { stub_request(:post, token_endpoint).to_raise(Faraday::ConnectionFailed.new("connection reset")) }

    it "raises a request error" do
      expect { token_importer.receive_token }.to raise_error(
        described_class::RequestError,
        "Access token request failed: connection reset"
      )
    end
  end
end
