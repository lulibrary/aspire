require 'base64'

require_relative 'base'

module Aspire
  module API
    # A wrapper class for the Aspire JSON API
    class JSON < Base
      # The default API root URL
      API_ROOT = "https://#{ASPIRE_DOMAIN}".freeze

      # The default authentication API root URL
      API_ROOT_AUTH = "https://#{ASPIRE_AUTH_DOMAIN}/1/oauth/tokens".freeze

      # @!attribute [rw] api_root
      #   @return [String] the base URL of the Aspire JSON APIs
      attr_accessor :api_root

      # @!attribute [rw] api_root_auth
      #   @return [String] the base URL of the Aspire Persona authentication API
      attr_accessor :api_root_auth

      # @!attribute [rw] api_version
      #   @return [Integer] the version of the Aspire JSON APIs
      attr_accessor :api_version

      # @!attribute [rw] rate_limit
      #   @return [Integer] the rate limit value from the most recent API call
      attr_accessor :rate_limit

      # @!attribute [rw] rate_remaining
      #   @return [Integer] the rate remaining value from the most recent API
      #     call (the number of calls remaining within the current limit period)
      attr_accessor :rate_remaining

      # @!attribute [rw] rate_reset
      #   @return [Integer] the rate reset value from the most recent API call
      #     (the time in seconds since the Epoch until the next limit period)
      attr_accessor :rate_reset

      # Initialises a new API instance
      # @param api_client_id [String] the API client ID
      # @param api_secret [String] the API secret associated with the client ID
      # @param tenancy_code [String] the Aspire short tenancy code
      # @param opts [Hash] API customisation options
      # @option opts [String] :api_root the base URL of the Aspire JSON APIs
      # @option opts [String] :api_root_auth the base URL of the Aspire Persona
      #   authentication API
      # @option opts [Integer] :api_version the version of the Aspire JSON APIs
      # @option opts [Logger] :logger a logger for activity logging
      # @option opts [Integer] :timeout the API call timeout period in seconds
      # @return [void]
      def initialize(api_client_id = nil, api_secret = nil, tenancy_code = nil,
                     **opts)
        super(tenancy_code, **opts)
        @api_client_id = api_client_id
        @api_secret = api_secret
        @api_token = nil
        self.api_root = opts[:api_root] || API_ROOT
        self.api_root_auth = opts[:api_root_auth] || API_ROOT_AUTH
        self.api_version = opts[:api_version] || 2
        rate_limit
      end

      # Returns a full Aspire JSON API URL. Full URLs are returned as-is,
      # partial endpoint paths are expanded with the API root, version and
      # tenancy code.
      # @param path [String] the full URL or partial endpoint path
      # @return [String] the full JSON API URL
      def api_url(path)
        return path if path.include?('//')
        "#{api_root}/#{api_version}/#{tenancy_code}/#{path}"
      end

      # Calls an Aspire JSON API method and returns the parsed JSON response
      # Additional keyword parameters are passed as query string parameters
      # to the API call.
      # @param path [String] the path of the API call
      # @param headers [Hash<String, String>] HTTP headers for the API call
      # @param options [Hash<String, Object>] options for the REST client
      # @param payload [String, nil] the data to post to the API call
      # @return [Hash] the parsed JSON content from the API response
      # @yield [response, data] Passes the REST client response and parsed JSON
      #   hash to the block
      # @yieldparam [RestClient::Response] the REST client response
      # @yieldparam [Hash] the parsed JSON data from the response
      def call(path, headers: nil, options: nil, payload: nil, **params)
        rest_options = call_rest_options(path,
                                         headers: headers, options: options,
                                         payload: payload, params: params)
        response, data = call_api_with_auth(**rest_options)
        yield(response, data) if block_given?
        data
      end

      private

      # Returns an Aspire OAuth API token. New tokens are retrieved from the
      #   Aspire Persona API and cached for subsequent API calls.
      # @param refresh [Boolean] if true, force retrieval of a new token
      # @return [String] the API token
      def api_token(refresh = false)
        # Return the cached token unless forcing a refresh
        return @api_token unless @api_token.nil? || refresh
        # Set the token to nil to indicate that there is no current valid token
        # in case an exception is thrown by the API call.
        @api_token = nil
        # Get and return the API token
        _response, data = call_api(**api_token_rest_options)
        @api_token = data['access_token']
      end

      # Returns the HTTP Basic authentication token
      # @return [String] the Basic authentication token
      def api_token_authorization
        Base64.strict_encode64("#{@api_client_id}:#{@api_secret}")
      end

      # Returns the HTTP headers for the token retrieval API call
      def api_token_rest_headers
        {
          Authorization: "basic #{api_token_authorization}",
          'Content-Type'.to_sym => 'application/x-www-form-urlencoded'
        }
      end

      def api_token_rest_options
        rest_options = {
          headers: api_token_rest_headers,
          payload: { grant_type: 'client_credentials' },
          url: api_root_auth
        }
        common_rest_options(rest_options)
        rest_options[:method] = :post
        rest_options
      end

      # Returns true if the HTTP response is an authentication failure
      # @param response [RestClient::Response] the REST client response
      # @return [Boolean] true on authentication failure, false otherwise
      def auth_failed(response)
        response && response.code == 401
      end

      # Performs custom HTTP response processing
      # @param response [RestClient::Response] the REST client response
      # @return [void]
      def call_api_response(response)
        rate_limit(headers: response.headers)
      end

      # Calls an authenticated Aspire API endpoint and processes the response.
      # The call is made first with the currently-cached authentication token.
      # If this fails due to authentication, the token is refreshed and the call
      # is repeated once with the new token.
      # @see (#call_api)
      def call_api_with_auth(**rest_options)
        refresh = false
        loop do
          token = api_token(refresh)
          rest_options[:headers]['Authorization'] = "Bearer #{token}"
          response, data = call_api(**rest_options)
          # Stop if we have a valid response or we've already tried to refresh
          #   the token.
          return response, data unless auth_failed(response) && !refresh
          # The API token may have expired, try one more time with a new token
          refresh = true
        end
      end

      # Sets API rate-limit parameters
      # @param headers [Hash] the HTTP response headers
      # @param limit [Integer] the default rate limit
      # @param remaining [Integer] the default remaining count
      # @param reset [Integer] the default reset period timestamp
      # @return [nil]
      def rate_limit(headers: {}, limit: nil, remaining: nil, reset: nil)
        reset = rate_limit_header(:reset, headers, reset)
        self.rate_limit = rate_limit_header(:limit, headers, limit)
        self.rate_remaining = rate_limit_header(:remaining, headers, remaining)
        self.rate_reset = reset ? Time(reset) : nil
      end

      # Returns the numeric value of a rate-limit header
      # @param header [String, Symbol] the header (minus x_ratelimit_ prefix)
      # @param headers [Hash] the HTTP response headers
      # @param default [Integer, nil] the default value if the header is missing
      # @return [Integer, nil] the numeric value of the header
      def rate_limit_header(header, headers, default)
        value = headers["x_ratelimit_#{header}".to_sym]
        value ? value.to_i : default
      end
    end
  end
end