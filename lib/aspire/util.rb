module Aspire
  # Utility methods mixin
  module Util
    # Regular expression to parse a Linked Data API URI
    LD_API_URI = Regexp.new('https?://(?<tenancy_host>[^/]*)/' \
                            '(?<type>[^/]*)/' \
                            '(?<id>[^/\.]*)' \
                            '(\.(?<format>[^/]*))?' \
                            '(/' \
                            '(?<child_type>[^/.]*)' \
                            '(/(?<child_id>[^/\.]*))?' \
                            '(\.(?<child_format>[^/]*))?' \
                            ')?(?<rest>.*)').freeze

    # Returns true if the first URL is the child of the second URL
    # @param url1 [Aspire::Caching::CacheEntry, String] the first URL
    # @param url2 [Aspire::Caching::CacheEntry, String] the second URL
    # @param api [Aspire::API::LinkedData] the API for generating canonical URLs
    # @param strict [Boolean] if true, the URL must be a parent of this entry,
    #   otherwise the URL must be a parent or the same as this entry
    # @return [Boolean] true if the URL is a child of the cache entry, false
    #   otherwise
    def child_url?(url1, url2, api = nil, strict: false)
      parent_url?(url2, url1, api, strict: strict)
    end

    # Returns a HH:MM:SS string given a Benchmark time
    # @param benchmark_time [Benchmark:Tms] the Benchmark time object
    # @return [String] the HH:HM:SS string
    def duration(benchmark_time)
      secs = benchmark_time.real
      hours = secs / 3600
      format('%2.2d:%2.2d:%2.2d', hours, hours % 60, secs % 60)
    end

    # Returns the ID of an object from its URL
    # @param u [String] the URL of the API object
    # @return [String] the object ID
    def id_from_uri(u, parsed: nil)
      parsed ||= parse_url(u)
      parsed[:id]
    end

    # Returns true if URI is a list item
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a list item, otherwise false
    def item?(uri)
      uri.include?('/items/')
    end

    # Returns the data for a URI from a parsed linked data API response
    # which may contain multiple objects
    # @param uri [String] the URI of the object
    # @param ld [Hash] the parsed JSON data from the Aspire linked data API
    # @return [Hash] the parsed JSON data for the URI
    def linked_data(uri, ld)
      uri = linked_data_path(uri)
      return nil unless uri && ld
      # The URI used to retrieve the data may be the canonical URI or a
      # tenancy aliases. We ignore the host part of the URIs and match just
      # the path
      ld.each { |u, data| return data if uri == linked_data_path(u) }
      # No match was found
      nil
    end

    # Returns the path of a URI
    # @param uri [String] the URI
    # @return [String, nil] the URI path or nil if invalid
    def linked_data_path(uri)
      URI.parse(uri).path
    rescue URI::InvalidComponentError, URI::InvalidURIError
      nil
    end

    # Returns true if URI is a list
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a list, otherwise false
    def list?(uri)
      uri.include?('/lists/')
    end

    # Returns true if a URL is a list URL, false otherwise
    # @param u [String] the URL of the API object
    # @return [Boolean] true if the URL is a list URL, false otherwise
    def list_url?(u = nil, parsed: nil)
      return false if (u.nil? || u.empty?) && parsed.nil?
      parsed ||= parse_url(u)
      child_type = parsed[:child_type]
      parsed[:type] == 'lists' && (child_type.nil? || child_type.empty?)
    end

    # Returns true if URI is a module
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a module, otherwise false
    def module?(uri)
      uri.include?('/modules/')
    end

    # Returns true if the first URL is the parent of the second URL
    # @param url1 [Aspire::Caching::CacheEntry, String] the first URL
    # @param url2 [Aspire::Caching::CacheEntry, String] the second URL
    # @param api [Aspire::API::LinkedData] the API for generating canonical URLs
    # @param strict [Boolean] if true, the first URL must be a parent of the
    #   second URL, otherwise the first URL must be a parent or the same as the
    #   second.
    # @return [Boolean] true if the URL has the same parent as this entry
    def parent_url?(url1, url2, api = nil, strict: false)
      u1 = url_for_comparison(url1, api, parsed: true)
      u2 = url_for_comparison(url2, api, parsed: true)
      # Both URLs must have the same parent
      return false unless u1[:type] == u2[:type] && u1[:id] == u2[:id]
      # Non-strict comparison requires only the same parent object
      return true unless strict
      # Strict comparison requires that this entry is a child of the URL
      u1[:child_type].nil? && !u2[:child_type].nil? ? true : false
    end

    # Returns the components of an object URL
    # @param url [String] the object URL
    # @return [MatchData, nil] the URI components:
    #   {
    #     tenancy_host: tenancy root (server name),
    #     type: type of primary object,
    #     id: ID of primary object,
    #     child_type: type of child object,
    #     child_id: ID of child object
    #   }
    def parse_url(url)
      url ? LD_API_URI.match(url) : nil
    end

    # Returns true if URI is a resource
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a resource, otherwise false
    def resource?(uri)
      uri.include?('/resources/')
    end

    # Returns true if URI is a section
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a section, otherwise false
    def section?(uri)
      uri.include?('/sections/')
    end

    # Returns a parsed or unparsed URL for comparison
    # @param url [Aspire::Caching::CacheEntry, String] the URL
    # @param api [Aspire::API::LinkedData] the API for generating canonical URLs
    # @param parsed [Boolean] if true, return a parsed URL, otherwise return
    #   an unparsed URL string
    # @return [Aspire::Caching::CacheEntry, String] the URL for comparison
    def url_for_comparison(url, api = nil, parsed: false)
      if url.is_a?(MatchData) && parsed
        url
      elsif parsed && url.respond_to?(:parsed_url)
        url.parsed_url
      elsif !parsed && url.respond_to?(url)
        url.url
      else
        result = api.nil? ? url.to_s : api.canonical_url(url.to_s)
        parsed ? parse_url(result) : result
      end
    end

    # Returns the path from the URL as a relative filename
    def url_path
      # Get the path component of the URL as a relative path
      filename = URI.parse(url).path
      filename.slice!(0) # Remove the leading /
      # Return the path with '.json' extension if not already present
      filename.end_with?('.json') ? filename : "#{filename}.json"
    rescue URI::InvalidComponentError, URI::InvalidURIError
      # Return nil if the URL is invalid
      nil
    end

    # Returns true if URI is a section
    # @param uri [String] the URI
    # @return [Boolean] true if the URI is a section, otherwise false
    def user?(uri)
      uri.include?('/users/')
    end
  end
end