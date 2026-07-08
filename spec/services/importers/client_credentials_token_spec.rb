# frozen_string_literal: true

require "rails_helper"

describe Importers::ClientCredentialsToken, backend: true do
  subject(:token_importer) { described_class.new }

  let(:endpoint) { "https://checkin.example/token" }
  let(:client_id) { "import-client" }
  let(:client_secret) { "import-secret" }

  around do |example|
    preserve_env("CHECKIN_HOST", "CHECKIN_TOKEN_ENDPOINT", "IMPORT_CLIENT_ID", "IMPORT_CLIENT_SECRET") { example.run }
  end

  before do
    ENV.delete("CHECKIN_HOST")
    ENV["CHECKIN_TOKEN_ENDPOINT"] = endpoint
    ENV["IMPORT_CLIENT_ID"] = client_id
    ENV["IMPORT_CLIENT_SECRET"] = client_secret
  end

  it "requests an access token with client credentials" do
    stub_request(:post, endpoint).with(
      body: {
        grant_type: "client_credentials",
        client_id: client_id,
        client_secret: client_secret
      },
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    ).to_return(status: 200, body: { access_token: "received-token" }.to_json)

    expect(token_importer.receive_token).to eq("received-token")
  end

  it "builds the token endpoint from CHECKIN_HOST and a relative endpoint path" do
    ENV["CHECKIN_HOST"] = "core-proxy.sandbox.eosc-beyond.eu"
    ENV["CHECKIN_TOKEN_ENDPOINT"] = "realms/core/protocol/openid-connect/token"

    stub_request(
      :post,
      "https://core-proxy.sandbox.eosc-beyond.eu/auth/realms/core/protocol/openid-connect/token"
    ).with(
      body: {
        grant_type: "client_credentials",
        client_id: client_id,
        client_secret: client_secret
      },
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded"
      }
    ).to_return(status: 200, body: { access_token: "received-token" }.to_json)

    expect(token_importer.receive_token).to eq("received-token")
  end

  it "builds the token endpoint from CHECKIN_HOST and an auth-prefixed relative endpoint path" do
    ENV["CHECKIN_HOST"] = "core-proxy.sandbox.eosc-beyond.eu"
    ENV["CHECKIN_TOKEN_ENDPOINT"] = "/auth/realms/core/protocol/openid-connect/token"

    stub_request(
      :post,
      "https://core-proxy.sandbox.eosc-beyond.eu/auth/realms/core/protocol/openid-connect/token"
    ).to_return(status: 200, body: { access_token: "received-token" }.to_json)

    expect(token_importer.receive_token).to eq("received-token")
  end

  it "detects a complete client credentials configuration" do
    expect(described_class).to be_configured
    expect(described_class).not_to be_partially_configured
  end

  it "detects a partial client credentials configuration" do
    ENV.delete("IMPORT_CLIENT_SECRET")

    expect(described_class).not_to be_configured
    expect(described_class).to be_partially_configured
  end

  it "raises a configuration error when a credential is missing" do
    ENV.delete("IMPORT_CLIENT_SECRET")

    expect { token_importer.receive_token }.to raise_error(
      described_class::ConfigurationError,
      "Missing import client credentials: IMPORT_CLIENT_SECRET"
    )
  end

  it "raises a configuration error when the token endpoint is missing" do
    ENV.delete("CHECKIN_TOKEN_ENDPOINT")

    expect { token_importer.receive_token }.to raise_error(
      described_class::ConfigurationError,
      "Missing CHECKIN_TOKEN_ENDPOINT or CHECKIN_HOST for import client credentials authentication"
    )
  end

  it "raises a configuration error when a relative token endpoint has no host" do
    ENV["CHECKIN_TOKEN_ENDPOINT"] = "realms/core/protocol/openid-connect/token"

    expect { token_importer.receive_token }.to raise_error(
      described_class::ConfigurationError,
      "Missing CHECKIN_TOKEN_ENDPOINT or CHECKIN_HOST for import client credentials authentication"
    )
  end

  it "raises a request error when the response does not include an access token" do
    stub_request(:post, endpoint).to_return(status: 200, body: { token_type: "Bearer" }.to_json)

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response does not include access_token"
    )
  end

  it "raises a request error when the response is empty" do
    stub_request(:post, endpoint).to_return(status: 200, body: "")

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response is empty"
    )
  end

  it "raises a request error when the response is not valid JSON" do
    stub_request(:post, endpoint).to_return(status: 200, body: "not-json")

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response is not valid JSON"
    )
  end

  def preserve_env(*keys)
    original = keys.index_with { |key| ENV.key?(key) ? ENV[key] : nil }
    yield
  ensure
    keys.each { |key| original[key].nil? ? ENV.delete(key) : ENV[key] = original[key] }
  end
end
