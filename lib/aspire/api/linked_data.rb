require 'uri'

require_relative 'base'

module Aspire
  module API
    # A wrapper class for the Aspire linked data API
    class LinkedData < Base
      # The tenancy domain
      TENANCY_DOMAIN = 'myreadinglists.org'.freeze

      # @!attribute [rw] tenancy_host_aliases
      #   @return [Array<String>] the list of non-canonical tenancy host names
      attr_accessor :tenancy_host_aliases

      # @!attribute [rw] tenancy_root
      #   @return [URI] the canonical root URI of the tenancy
      attr_accessor :tenancy_root

      # Initialises a new LinkedData instance
      def initialize(tenancy_code, **opts)
        super(tenancy_code, **opts)
        self.tenancy_host_aliases = opts[:tenancy_host_aliases]
        self.tenancy_root = opts[:tenancy_root]
      end

      # Returns a full Aspire tenancy URL from a partial resource path
      # @param path [String] the partial resource path
      # @return [String] the full tenancy URL
      def api_url(path)
        path.include?('//') ? path : "#{tenancy_root}/#{path}"
      end

      # Returns parsed JSON data for a URI using the Aspire linked data API
      # @param url [String] the partial (minus the tenancy root) or complete
      #   tenancy URL of the resource
      # @return [Hash] the parsed JSON content from the API response
      # @yield [response, data] Passes the REST client response and parsed JSON
      #   hash to the block
      # @yieldparam response [RestClient::Response] the REST client response
      # @yieldparam data [Hash] the parsed JSON data from the response
      def call(url)
        url = api_url(url)
        url = "#{url}.json" unless url.end_with?('.json')
        rest_options = call_rest_options(url)
        response, data = call_api(**rest_options)
        yield(response, data) if block_given?
        data
      end

      # Returns the canonical host name for an Aspire tenancy
      # @return [String] the canonical host name for the tenancy
      def canonical_host
        "#{tenancy_code}.#{TENANCY_DOMAIN}"
      end

      # Converts an Aspire tenancy alias or URL to canonical form
      # @param url [String] an Aspire host name or URL
      # @return [String, nil] the equivalent canonical host name or URL using
      #   the tenancy base URL, or nil if the host is not a valid tenancy alias
      def canonical_url(url)
        # Ensure the host name is valid
        url = uri(url)
        return nil unless valid_host?(url)
        # Replace the host name with the canonical host name
        url.host = tenancy_host
        # Add '.json' suffix if required
        url.path = "#{url.path}.json" unless url.path.end_with?('.json')
        # Return the URL string
        url.to_s
      rescue URI::InvalidComponentError, URI::InvalidURIError
        return nil
      end

      # Returns the canonical tenancy host name
      # @return [String] the canonical tenancy host name
      def tenancy_host
        @tenancy_root.host
      end

      # Sets the list of tenancy aliases
      # @param aliases [Array<String>] the list of tenancy aliases
      # @return [void]
      def tenancy_host_aliases=(aliases)
        if aliases.nil?
          @tenancy_host_aliases = [canonical_host]
        elsif aliases.empty?
          @tenancy_host_aliases = []
        else
          # Extract the host name of each alias
          aliases = [aliases] unless aliases.is_a?(Array)
          aliases = aliases.map { |a| uri_host(a) }
          @tenancy_host_aliases = aliases.reject { |a| a.nil? || a.empty? }
        end
      end

      # Sets the tenancy root URL
      # @param url [String] the tenancy root URL
      # @return [URI] the tenancy root URI instance
      # @raise [URI::InvalidComponentError, URI::InvalidURIError] if the URL
      #   is invalid
      def tenancy_root=(url)
        # Use the default tenancy host name if no URI is specified
        url = canonical_host if url.nil? || url.empty?
        # If the URI contains no path components, uri.host is nil and uri.path
        # contains the whole string, so use this as the host name
        uri = URI.parse(url)
        if uri.host.nil? || uri.host.empty?
          uri.host = uri.path
          uri.path = ''
        end
        # Set the URI scheme if required
        uri.scheme ||= SCHEME
        @tenancy_root = uri
      end

      # Returns true if host is a valid tenancy hostname
      # @param host [String, URI] the hostname
      # @return [Boolean] true if the hostname is valid, false otherwise
      def valid_host?(host)
        return false if host.nil?
        host = host.host if host.is_a?(URI)
        host == tenancy_host || tenancy_host_aliases.include?(host)
      end

      # Returns true if URL is a valid tenancy URL or host
      # @param url [String] the URL or host
      # @return [Boolean] true if the URL or host is valid, false otherwise
      def valid_url?(url)
        url.nil? ? false : valid_host?(uri(url))
      rescue URI::InvalidComponentError, URI::InvalidURIError
        false
      end
    end
  end
end