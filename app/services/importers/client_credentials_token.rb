# frozen_string_literal: true

require "uri"

class Importers::ClientCredentialsToken
  class RequestError < StandardError
  end

  attr_reader :faraday

  def initialize(faraday: Faraday)
    @faraday = faraday
  end

  def receive_token
    response = faraday.post(oidc_config.token_endpoint, token_query_params, request_headers)
    raise RequestError, "Access token response is empty" if response&.body.blank?

    token = JSON.parse(response.body)["access_token"]
    return token if token.present?

    raise RequestError, "Access token response does not include access_token"
  rescue JSON::ParserError
    raise RequestError, "Access token response is not valid JSON"
  rescue Faraday::Error => e
    raise RequestError, "Access token request failed: #{e.message}"
  end

  private

  def request_headers
    { "Content-Type" => "application/x-www-form-urlencoded" }
  end

  def token_query_params
    URI.encode_www_form(
      grant_type: "client_credentials",
      client_id: ENV.fetch("IMPORT_CLIENT_ID"),
      client_secret: ENV.fetch("IMPORT_CLIENT_SECRET")
    )
  end

  def oidc_config
    @oidc_config ||= OmniAuth::Strategies::OpenIDConnect.new(nil, provider.options).config
  end

  def provider
    Devise.omniauth_configs[:checkin]
  end
end
