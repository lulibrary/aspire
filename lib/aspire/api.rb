require 'aspire/api/json'
require 'aspire/api/linked_data'

# module Aspire
  # # Wrapper for the Talis Aspire API
  # class API
  #   # Domain names
  #   TALIS_DOMAIN = 'talis.com'.freeze
  #   ASPIRE_DOMAIN = "rl.#{TALIS_DOMAIN}".freeze
  #   ASPIRE_AUTH_DOMAIN = "users.#{TALIS_DOMAIN}".freeze
  #   TENANCY_DOMAIN = 'myreadinglists.org'.freeze
  #
  #   # The default API root URL
  #   API_ROOT = "https://#{ASPIRE_DOMAIN}".freeze
  #
  #   # The default authentication API root URL
  #   API_ROOT_AUTH = "https://#{ASPIRE_AUTH_DOMAIN}/1/oauth/tokens".freeze
  #
  #   # The default URL scheme
  #   SCHEME = 'http'.freeze
  #
  #   # @!attribute [rw] api_root
  #   #   @return [String] the base URL of the Aspire JSON APIs
  #   attr_accessor :api_root
  #
  #   # @!attribute [rw] api_root_auth
  #   #   @return [String] the base URL of the Aspire Persona authentication API
  #   attr_accessor :api_root_auth
  #
  #   # @!attribute [rw] api_version
  #   #   @return [Integer] the version of the Aspire JSON APIs
  #   attr_accessor :api_version
  #
  #   # @!attribute [rw] logger
  #   #   @return [Logger] a logger for activity logging
  #   attr_accessor :logger
  #
  #   # @!attribute [rw] rate_limit
  #   #   @return [Integer] the rate limit value from the most recent API call
  #   attr_accessor :rate_limit
  #
  #   # @!attribute [rw] rate_remaining
  #   #   @return [Integer] the rate remaining value from the most recent API call
  #   #     (the number of calls remaining within the current limit period)
  #   attr_accessor :rate_remaining
  #
  #   # @!attribute [rw] rate_reset
  #   #   @return [Integer] the rate reset value from the most recent API call
  #   #     (the time in seconds since the Epoch until the next limit period)
  #   attr_accessor :rate_reset
  #
  #   # @!attribute [rw] ssl_ca_file
  #   #   @return [String] the SSL CA certificate file
  #   attr_accessor :ssl_ca_file
  #
  #   # @!attribute [rw] ssl_ca_path
  #   #   @return [String] the SSL CA certificate directory path
  #   attr_accessor :ssl_ca_path
  #
  #   # @!attribute [rw] ssl_cert_store
  #   #   @return [String] the SSL CA certificate store
  #   attr_accessor :ssl_cert_store
  #
  #   # @!attribute [rw] tenancy_code
  #   #   @return [String] the Aspire short tenancy code
  #   attr_accessor :tenancy_code
  #
  #   # @!attribute [rw] tenancy_host_aliases
  #   #   @return [Array<String>] the list of non-canonical tenancy host names
  #   attr_accessor :tenancy_host_aliases
  #
  #   # @!attribute [rw] tenancy_root
  #   #   @return [URI] the canonical root URI of the tenancy
  #   attr_accessor :tenancy_root
  #
  #   # @!attribute [rw] timeout
  #   #   @return [Integer] the timeout period in seconds for API calls
  #   attr_accessor :timeout
  #
  #   # Initialises a new API instance
  #   # @param api_client_id [String] the API client ID
  #   # @param api_secret [String] the API secret associated with the client ID
  #   # @param tenancy_code [String] the Aspire short tenancy code
  #   # @param opts [Hash] API customisation options
  #   # @option opts [String] :api_root the base URL of the Aspire JSON APIs
  #   # @option opts [String] :api_root_auth the base URL of the Aspire Persona
  #   #   authentication API
  #   # @option opts [Integer] :api_version the version of the Aspire JSON APIs
  #   # @option opts [Logger] :logger a logger for activity logging
  #   # @option opts [Array<String>] :tenancy_host_aliases a list of non-canoncial
  #   #   tenancy host names
  #   # @option opts [String] :tenancy_root the canonical tenancy base URL
  #   # @option opts [Integer] :timeout the API call timeout period in seconds
  #   # @return [void]
  #   def initialize(api_client_id = nil, api_secret = nil, tenancy_code = nil,
  #                  **opts)
  #     self.tenancy_code = tenancy_code
  #     @api_client_id = api_client_id
  #     @api_secret = api_secret
  #     @api_token = nil
  #     options(opts)
  #     rate_limit
  #     RestClient.log = logger if logger
  #   end
  #
  #   # Calls an Aspire JSON API method and returns the parsed JSON response
  #   # Any undocumented keyword parameters are passed as query string parameters
  #   #   to the API call.
  #   # @param path [String] the path of the API call
  #   # @param headers [Hash<String, String>] HTTP headers for the API call
  #   # @param options [Hash<String, Object>] options for the REST client
  #   # @param payload [String, nil] the data to post to the API call
  #   # @return [Hash] the parsed JSON content from the API response
  #   # @yield [response, data] Passes the REST client response and parsed JSON
  #   #   hash to the block
  #   # @yieldparam [RestClient::Response] the REST client response
  #   # @yieldparam [Hash] the parsed JSON data from the response
  #   def call(path, headers: nil, options: nil, payload: nil, **params)
  #     rest_options = call_rest_options(path,
  #                                      headers: headers, options: options,
  #                                      payload: payload, params: params)
  #     response, data = call_api_with_auth(**rest_options)
  #     yield(response, data) if block_given?
  #     data
  #   end
  #
  #   # Converts an Aspire tenancy alias or URL to canonical form
  #   # @param url [String] an Aspire host name or URL
  #   # @return [String, nil] the equivalent canonical host name or URL using the
  #   #   tenancy base URL, or nil if the host is not a valid tenancy alias
  #   def canonical(url)
  #     # Parse the URL
  #     url = url.to_s
  #     begin
  #       uri = URI.parse(url)
  #     rescue URI::InvalidComponentError, URI::InvalidURIError
  #       return nil
  #     end
  #     # Ensure the host name is valid
  #     return nil unless valid_host?(uri.host || url)
  #     # Return the canonical host name if a host name was supplied
  #     return tenancy_root unless uri.host
  #     # Otherwise return the canonical URL
  #     uri.host = tenancy_root
  #     uri.to_s
  #   end
  #
  #   # Returns parsed JSON data for a URI using the Aspire linked data API
  #   # @param url [String] the partial (minus the tenancy root) or complete
  #   #   tenancy URL of the resource
  #   # @return [Hash] the parsed JSON content from the API response
  #   # @yield [response, data] Passes the REST client response and parsed JSON
  #   #   hash to the block
  #   # @yieldparam response [RestClient::Response] the REST client response
  #   # @yieldparam data [Hash] the parsed JSON data from the response
  #   def get_json(url)
  #     url = tenancy_url(url)
  #     url = "#{url}.json" unless url.end_with?('.json')
  #     rest_options = call_rest_options(url)
  #     response, data = call_api(**rest_options)
  #     yield(response, data) if block_given?
  #     data
  #   end
  #
  #   # Returns the canonical tenancy host name
  #   # @return [String] the canonical tenancy host name
  #   def tenancy_host
  #     @tenancy_root.host
  #   end
  #
  #   # Sets the list of tenancy aliases
  #   # @param aliases [Array<String>] the list of tenancy aliases
  #   # @return [void]
  #   def tenancy_host_aliases=(aliases)
  #     if aliases.nil? || aliases.empty?
  #       @tenancy_host_aliases = []
  #     else
  #       # Extract the host name of each alias
  #       # - URI.parse('hostname') without scheme etc does not set the host,
  #       #   so if this is nil, we use the alias string as given
  #       aliases = [aliases] unless aliases
  #       aliases = aliases.map do |a|
  #         a = a.to_s
  #         URI.parse(a).host || a
  #       end
  #       @tenancy_host_aliases = aliases.reject { |a| a.nil? || a.empty? }
  #     end
  #   end
  #
  #   # Sets the tenancy root URI
  #   # @param uri [String] the tenancy root URI
  #   # @return [URI] the tenancy root URI instance
  #   def tenancy_root=(uri)
  #     # Use the default tenancy host name if no URI is specified
  #     uri = "#{tenancy_code}.#{TENANCY_DOMAIN}" if uri.nil? || uri.empty?
  #     # If the URI contains no path components, uri.host is nil and uri.path
  #     # contains the whole string, so use this as the host name
  #     uri = URI.parse(uri)
  #     uri.host = uri.path if uri.host.nil? || uri.host.empty?
  #     # Set the URI scheme if required
  #     uri.scheme ||= SCHEME
  #     @tenancy_root = uri
  #   end
  #
  #   # Returns a full Aspire tenancy URL from a partial resource path
  #   # @param path [String] the partial resource path
  #   # @return [String] the full tenancy URL
  #   def tenancy_url(path)
  #     path.include?('//') ? path : "#{tenancy_root}/#{path}"
  #   end
  #
  #   # Returns a full Aspire JSON API URL. Full URLs are returned as-is,
  #   # partial endpoint paths are expanded with the API root, version and
  #   # tenancy code.
  #   # @param path [String] the full URL or partial endpoint path
  #   # @return [String] the full JSON API URL
  #   def url(path)
  #     return path if path.include?('//')
  #     "#{api_root}/#{api_version}/#{tenancy_code}/#{path}"
  #   end
  #
  #   # Returns true if host is a valid tenancy hostname
  #   # @param host [String, URI] the hostname
  #   # @return [Boolean] true if the hostname is valid, false otherwise
  #   def valid_host?(host)
  #     return false if host.nil? || host.empty?
  #     host = host.host if host.is_a?(URI)
  #     host == tenancy_host || tenancy_host_aliases.include?(host)
  #   end
  #
  #   # Returns true if URL is a valid tenancy URL or host
  #   # @param url [String] the URL or host
  #   # @return [Boolean] true if the URL or host is valid, false otherwise
  #   def valid_url?(url)
  #     url.nil? || url.empty? ? false : valid_host?(uri(url))
  #   end
  #
  #   private
  #
  #   # Returns an Aspire OAuth API token. New tokens are retrieved from the
  #   #   Aspire Persona API and cached for subsequent API calls.
  #   # @param refresh [Boolean] if true, force retrieval of a new token
  #   # @return [String] the API token
  #   def api_token(refresh = false)
  #     # Return the cached token unless forcing a refresh
  #     return @api_token unless @api_token.nil? || refresh
  #     # Set the token to nil to indicate that there is no current valid token
  #     # in case an exception is thrown by the API call.
  #     @api_token = nil
  #     # Get and return the API token
  #     _response, data = call_api(**api_token_rest_options)
  #     @api_token = data['access_token']
  #   end
  #
  #   # Returns the HTTP Basic authentication token
  #   # @return [String] the Basic authentication token
  #   def api_token_authorization
  #     Base64.strict_encode64("#{@api_client_id}:#{@api_secret}")
  #   end
  #
  #   # Returns the HTTP headers for the token retrieval API call
  #   def api_token_rest_headers
  #     {
  #       Authorization: "basic #{api_token_authorization}",
  #       'Content-Type'.to_sym => 'application/x-www-form-urlencoded'
  #     }
  #   end
  #
  #   def api_token_rest_options
  #     rest_options = {
  #       headers: api_token_rest_headers,
  #       payload: { grant_type: 'client_credentials' },
  #       url: api_root_auth
  #     }
  #     common_rest_options(rest_options)
  #     rest_options[:method] = :post
  #     rest_options
  #   end
  #
  #   # Returns true if the HTTP response is an authentication failure
  #   # @param response [RestClient::Response] the REST client response
  #   # @return [Boolean] true on authentication failure, false otherwise
  #   def auth_failed(response)
  #     response && response.code == 401
  #   end
  #
  #   # Calls an Aspire API endpoint and processes the response.
  #   # Keyword parameters are passed directly to the REST client
  #   # @return [(RestClient::Response, Hash)] the REST client response and parsed
  #   #   JSON data from the response
  #   def call_api(**rest_options)
  #     begin
  #       response = RestClient::Request.execute(**rest_options)
  #       json = response && !response.empty? ? JSON.parse(response.to_s) : nil
  #       rate_limit(headers: response.headers)
  #       return response, json
  #     rescue RestClient::ExceptionWithResponse => e
  #       # json = JSON.parse(response.to_s) if response && !response.empty?
  #       return e.response, nil
  #     end
  #   end
  #
  #   # Calls an authenticated Aspire API endpoint and processes the response.
  #   # The call is made first with the currently-cached authentication token.
  #   # If this fails due to authentication, the token is refreshed and the call
  #   # is repeated once with the new token.
  #   # @see (#call_api)
  #   def call_api_with_auth(**rest_options)
  #     refresh = false
  #     loop do
  #       token = api_token(refresh)
  #       rest_options[:headers]['Authorization'] = "Bearer #{token}"
  #       response, data = call_api(**rest_options)
  #       # Stop if we have a valid response or we've already tried to refresh
  #       #   the token.
  #       return response, data unless auth_failed(response) && !refresh
  #       # The API token may have expired, try one more time with a new token
  #       refresh = true
  #     end
  #   end
  #
  #   # Returns the HTTP headers for an API call
  #   # @param headers [Hash] optional headers to add to the API call
  #   # @param params [Hash] query string parameters for the API call
  #   # @return [Hash] the HTTP headers
  #   def call_rest_headers(headers, params)
  #     rest_headers = {}.merge(headers || {})
  #     rest_headers[:params] = params if params && !params.empty?
  #   end
  #
  #   # Returns the REST client options for an API call
  #   # @param path [String] the path of the API call
  #   # @param headers [Hash<String, String>] HTTP headers for the API call
  #   # @param options [Hash<String, Object>] options for the REST client
  #   # @param params [Hash<String, String>] query string parameters
  #   # @param payload [String, nil] the data to post to the API call
  #   # @return [Hash] the REST client options
  #   def call_rest_options(path, headers: nil, options: nil, params: nil,
  #                         payload: nil)
  #     rest_headers = call_rest_headers(headers, params)
  #     rest_options = {
  #       headers: rest_headers,
  #       url: url(path)
  #     }
  #     common_rest_options(rest_options)
  #     rest_options[:payload] = payload if payload
  #     rest_options.merge(options) if options
  #     rest_options[:method] ||= payload ? :post : :get
  #     rest_options
  #   end
  #
  #   # Sets the REST client options common to all API calls
  #   # @param rest_options [Hash] the REST client options
  #   # @return [Hash] the REST client options
  #   def common_rest_options(rest_options)
  #     rest_options[:ssl_ca_file] = ssl_ca_file if ssl_ca_file
  #     rest_options[:ssl_ca_path] = ssl_ca_path if ssl_ca_path
  #     rest_options[:ssl_cert_store] = ssl_cert_store if ssl_cert_store
  #     rest_options[:timeout] = timeout > 0 ? timeout : nil
  #     rest_options
  #   end
  #
  #   # Sets API options
  #   # @param options [Hash] the options hash
  #   # @return [void]
  #   def options(options = {})
  #     self.api_root = options[:api_root] || API_ROOT
  #     self.api_root_auth = options[:api_root_auth] || API_ROOT_AUTH
  #     self.api_version = options[:api_version] || 2
  #     self.logger = options[:logger]
  #     self.ssl_ca_file = options[:ssl_ca_file]
  #     self.ssl_ca_path = options[:ssl_ca_path]
  #     self.ssl_cert_store = options[:ssl_cert_store]
  #     self.timeout = options[:timeout].to_i
  #     self.tenancy_host_aliases = options_tenancy_host_aliases(options)
  #     self.tenancy_root = options[:tenancy_root]
  #   end
  #
  #   # Returns the tenancy host aliases
  #   # @param options [Hash] the options hash
  #   # @return [Array<String>] the list of tenancy host aliases
  #   def options_tenancy_host_aliases(options)
  #     options[:tenancy_host_aliases] || ["#{tenancy_code}.#{ASPIRE_DOMAIN}"]
  #   end
  #
  #   # Sets API rate-limit parameters
  #   # @param headers [Hash] the HTTP response headers
  #   # @param limit [Integer] the default rate limit
  #   # @param remaining [Integer] the default remaining count
  #   # @param reset [Integer] the default reset period timestamp
  #   # @return [nil]
  #   def rate_limit(headers: {}, limit: nil, remaining: nil, reset: nil)
  #     reset = rate_limit_header(:reset, headers, reset)
  #     self.rate_limit = rate_limit_header(:limit, headers, limit)
  #     self.rate_remaining = rate_limit_header(:remaining, headers, remaining)
  #     self.rate_reset = reset ? Time(reset) : nil
  #   end
  #
  #   # Returns the numeric value of a rate-limit header
  #   # @param header [String, Symbol] the header (minus the x_ratelimit_ prefix)
  #   # @param headers [Hash] the HTTP response headers
  #   # @param default [Integer, nil] the default value if the header is missing
  #   # @return [Integer, nil] the numeric value of the header
  #   def rate_limit_header(header, headers, default)
  #     value = headers["x_ratelimit_#{header}".to_sym]
  #     value ? value.to_i : default
  #   end
  #
  #   # Returns a URI instance for a string, treating URIs with no path components
  #   # as host names.
  #   # @param uri [String] the URI
  #   # @return [URI] the URI instance
  #   # def uri(uri)
  #   #   # Use the default tenancy host name if no URI is specified
  #   #   uri = "#{tenancy_code}.#{TENANCY_DOMAIN}" if uri.nil? || uri.empty?
  #   #   # If the URI contains no path components, uri.host is nil and uri.path
  #   #   # contains the whole string, so use this as the host name
  #   #   uri = URI.parse(uri)
  #   #   uri.host = uri.path if uri.host.nil? || uri.host.empty?
  #   #   # Set the URI scheme if required
  #   #   uri.scheme ||= SCHEME
  #   #   # Return the URI instance
  #   #   uri
  #   # end
  # end
#end