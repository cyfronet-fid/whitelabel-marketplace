# frozen_string_literal: true

require "rails_helper"

describe Importers::ClientCredentialsToken, backend: true do
  subject(:token_importer) { described_class.new }

  let(:client_id) { "import-client" }
  let(:client_secret) { "import-secret" }
  let(:token_host) { "checkin.example" }
  let(:token_endpoint) { "/auth/realms/core/protocol/openid-connect/token" }
  let(:token_url) { "https://#{token_host}#{token_endpoint}" }

  around do |example|
    preserve_env("IMPORT_CLIENT_ID", "IMPORT_CLIENT_SECRET") { example.run }
  end

  before do
    ENV["IMPORT_CLIENT_ID"] = client_id
    ENV["IMPORT_CLIENT_SECRET"] = client_secret

    allow(Devise.omniauth_configs[:checkin])
      .to receive(:options)
      .and_return(
        client_options: { 
          host: token_host, 
          token_endpoint: token_endpoint 
        }
      )
  end

  it "requests an access token with client credentials from the checkin token endpoint" do
    stub_request(:post, token_url).with(
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

  it "builds the token url from the checkin omniauth client options" do
    allow(Devise.omniauth_configs[:checkin])
      .to receive(:options)
      .and_return(
        client_options: { 
          host: "core-proxy.sandbox.eosc-beyond.eu", 
          token_endpoint: "/token" 
        }
      )

    stub_request(:post, "https://core-proxy.sandbox.eosc-beyond.eu/token")
      .to_return(status: 200, body: { access_token: "received-token" }.to_json)

    expect(token_importer.receive_token).to eq("received-token")
  end

  it "raises a key error when IMPORT_CLIENT_ID is missing" do
    ENV.delete("IMPORT_CLIENT_ID")

    expect { token_importer.receive_token }.to raise_error(KeyError)
  end

  it "raises a key error when IMPORT_CLIENT_SECRET is missing" do
    ENV.delete("IMPORT_CLIENT_SECRET")

    expect { token_importer.receive_token }.to raise_error(KeyError)
  end

  it "raises a request error when the response does not include an access token" do
    stub_request(:post, token_url).to_return(status: 200, body: { token_type: "Bearer" }.to_json)

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response does not include access_token"
    )
  end

  it "raises a request error when the response is empty" do
    stub_request(:post, token_url).to_return(status: 200, body: "")

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response is empty"
    )
  end

  it "raises a request error when the response is not valid JSON" do
    stub_request(:post, token_url).to_return(status: 200, body: "not-json")

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token response is not valid JSON"
    )
  end

  it "raises a request error when the request fails" do
    stub_request(:post, token_url).to_raise(Faraday::ConnectionFailed.new("connection reset"))

    expect { token_importer.receive_token }.to raise_error(
      described_class::RequestError,
      "Access token request failed: connection reset"
    )
  end

  def preserve_env(*keys)
    original = keys.index_with { |key| ENV.key?(key) ? ENV[key] : nil }
    yield
  ensure
    keys.each { |key| original[key].nil? ? ENV.delete(key) : ENV[key] = original[key] }
  end
end
