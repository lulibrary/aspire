require 'json'
require 'uri'

require 'rest-client'

require 'retry'

module Aspire
  module API
    # The base class for Aspire API wrappers
    class Base
      # Domain names
      TALIS_DOMAIN = 'talis.com'.freeze
      ASPIRE_DOMAIN = "rl.#{TALIS_DOMAIN}".freeze
      ASPIRE_AUTH_DOMAIN = "users.#{TALIS_DOMAIN}".freeze

      # The default URL scheme
      SCHEME = 'http'.freeze

      # SSL options
      SSL_OPTS = %i[ssl_ca_file ssl_ca_path ssl_cert_store].freeze

      # @!attribute [rw] logger
      #   @return [Logger] a logger for activity logging
      attr_accessor :logger

      # @!attribute [rw] ssl
      #   @return [Hash] SSL options
      attr_accessor :ssl

      # @!attribute [rw] tenancy_code
      #   @return [String] the Aspire short tenancy code
      attr_accessor :tenancy_code

      # @!attribute [rw] timeout
      #   @return [Integer] the timeout period in seconds for API calls
      attr_accessor :timeout

      # Initialises a new API instance
      # @param tenancy_code [String]
      # @option opts [Logger] :logger the API activity logger
      # @option opts [Integer] :timeout the API timeout in seconds
      # @option opts [String] :ssl_ca_file the certificate authority filename
      # @option opts [String] :ssl_ca_path the certificate authority directory
      # @option opts [String] :ssl_cert_store the certificate authority store
      def initialize(tenancy_code, **opts)
        self.logger = opts[:logger]
        self.tenancy_code = tenancy_code
        self.timeout = opts[:timeout] || 0
        # Retry options
        initialize_retry(opts)
        # SSL options
        initialize_ssl(opts)
        # Set the RestClient logger
        RestClient.log = logger if logger
      end

      # Returns a full API URL from a partial path
      # @abstract Subclasses must implement this method
      # @param path [String] a full or partial API URL
      # @return [String] the full API URL
      def api_url(path)
        path
      end

      private

      # Calls an Aspire API endpoint and processes the response.
      # Keyword parameters are passed directly to the REST client
      # @return [(RestClient::Response, Hash)] the REST client response and
      #   parsed JSON data from the response
      def call_api(**rest_options)
        @retry.do do
          res = RestClient::Request.execute(**rest_options)
          json = res && !res.empty? ? ::JSON.parse(res.to_s) : nil
          call_api_response(res) if respond_to?(:call_api_response)
          [res, json]
        end
      end

      # Returns the HTTP headers for an API call
      # @param headers [Hash] optional headers to add to the API call
      # @param params [Hash] query string parameters for the API call
      # @return [Hash] the HTTP headers
      def call_rest_headers(headers, params)
        rest_headers = {}.merge(headers || {})
        rest_headers[:params] = params if params && !params.empty?
        rest_headers
      end

      # Returns the REST client options for an API call
      # @param path [String] the path of the API call
      # @param headers [Hash<String, String>] HTTP headers for the API call
      # @param options [Hash<String, Object>] options for the REST client
      # @param params [Hash<String, String>] query string parameters
      # @param payload [String, nil] the data to post to the API call
      # @return [Hash] the REST client options
      def call_rest_options(path, headers: nil, options: nil, params: nil,
                            payload: nil)
        rest_headers = call_rest_headers(headers, params)
        rest_options = {
          headers: rest_headers,
          url: api_url(path)
        }
        common_rest_options(rest_options)
        rest_options[:payload] = payload if payload
        rest_options.merge!(options) if options
        rest_options[:method] ||= payload ? :post : :get
        rest_options
      end

      # Sets the REST client options common to all API calls
      # @param rest_options [Hash] the REST client options
      # @return [Hash] the REST client options
      def common_rest_options(rest_options)
        SSL_OPTS.each { |opt| rest_options[opt] = ssl[opt] if ssl[opt] }
        rest_options[:timeout] = timeout > 0 ? timeout : nil
        rest_options
      end

      # Initialises retry options
      # @param opts [Hash] the options hash
      # @return [void]
      def initialize_retry(opts)
        @retry = Retry::Engine.new(delay: opts[:retry_delay] || 5,
                                   exceptions: initialize_retry_exceptions,
                                   handlers: initialize_retry_handlers,
                                   tries: opts[:retries] || 5)
      end

      # Returns a hash of retriable exceptions
      # @return [Hash<Exception|Symbol, Boolean>] the retriable exceptions
      def initialize_retry_exceptions
        [
          RestClient::ExceptionWithResponse,
          RestClient::ServerBrokeConnection,
          RestClient::Exceptions::Timeout
        ].push(*Retry::Exceptions::SOCKET_EXCEPTIONS)
      end

      # Returns a hash of retry handlers
      # @return [Hash<Exception|Symbol, Proc>] the retry handlers
      def initialize_retry_handlers
        {
          :default => proc { |e, _t| log_exception(e) },
          :retry => proc { |_e, t| logger.debug("Retrying (#{t} tries left)") },
          RestClient::ExceptionWithResponse => proc do |e, _t|
            log_exception(e, debug: "Response: #{e}")
            # json = ::JSON.parse(response.to_s) if response && !response.empty?
            raise Retry::StopRetry.new([e.response, nil])
          end
        }
      end

      # Sets the SSL options
      # @param opts [Hash] the options hash
      def initialize_ssl(opts)
        self.ssl = {}
        SSL_OPTS.each { |opt| ssl[opt] = opts[opt] }
      end

      # Logs an exception
      # @param e [Exception] the exception
      # @param debug [String] extra debugging message
      def log_exception(e, debug: nil)
        return unless logger
        logger.error(e.to_s)
        logger.debug(e.backtrace.join('\n'))
        logger.debug(debug) if debug
      end

      # Returns a URI instance for a URL, treating URLs without schemes or path
      # components as host names
      # @param url [String] the URL
      # @return [URI] the URI instance
      def uri(url)
        url = URI.parse(url) unless url.is_a?(URI)
        if url.host.nil? && url.scheme.nil?
          url.host = url.path
          url.path = ''
        end
        url.scheme ||= 'http'
        url
      rescue URI::InvalidComponentError, URI::InvalidURIError
        nil
      end

      # Returns the host name of a URL, treating URLs without schemes or path
      # components as host names
      # @param url [String] the URL
      # @return [String] the host name of the URL
      def uri_host(url)
        url = uri(url)
        url ? url.host : nil
      end
    end
  end
end