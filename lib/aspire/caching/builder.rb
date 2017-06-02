require 'json'
require 'logger'
require 'uri'

require 'aspire/caching/cache_entry'
require 'aspire/caching/cache_logger'
require 'aspire/caching/exceptions'
require 'aspire/caching/util'

module Aspire
  # Tools for building a cache from the Aspire APIs
  module Caching
    # Caches Aspire API objects and their references
    class Builder
      include Util

      # @!attribute [rw] cache
      #   @return [Aspire::Caching::Cache] the Aspire cache
      attr_accessor :cache

      # @!attribute [rw] logger
      #   @return [Aspire::Caching::CacheLogger] the cache activity logger
      attr_accessor :logger

      # Initialises a new Cache instance
      # @param cache [Aspire::Caching::Cache] the Aspire cache
      # @param clear [Boolean] if true, clear the cache, otherwise
      #   leave any existing cache content intact
      # @param logger [Logger] the cache activity logger
      # @return [void]
      def initialize(cache = nil, clear: false, logger: nil)
        self.cache = cache
        self.logger = Aspire::Caching::CacheLogger.new(logger)
        cache.clear if clear
      end

      # Caches an Aspire linked data API object.
      #    Use write(url) to build a cache for the first time.
      #    Use write(url, refresh: true) to reload parts of the cache.
      # @param url [String] the URL of the API object
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON data to be written to the cache;
      #   if omitted, this is read from the API
      # @param nested [Boolean] if true, this is a recursive call from a parent
      #   object, otherwise this is the initial call
      # @return [void]
      def write(url, urls = {}, data = nil, nested: false)
        #
        # Parsed data from the Linked Data API has the following structure:
        # { url => {primary-object},
        #   related-url1 => {related-object1}, ... }
        # where url => {primary-object} is the object referenced by the url
        # parameter, and the related URLs/objects are objects referenced by
        # the primary object and included in the API response.
        #
        # The primary and related objects are written to the caching before any
        # object references within the primary and related objects are followed.
        # This should reduce unnecessary duplication of API calls.
        #
        # Some objects with a linked data URL are not accessible through that
        # API(e.g. users /users/<user-id> are not accessible, but user notes
        # /users/<user-id>/notes<note-id> are accessible).
        #
        # Some objects with a linked data URL are accessible though the API but
        # do not return JSON-LD (e.g. events /events/<event-id> return regular
        # JSON rather than JSON-LD). These objects are cached but no attempt is
        # made to follow LD references within them.
        #
        entry = CacheEntry.new(url, cache)
        write_data(entry, urls, data) if write?(entry, urls, nested)
      end

      private

      # Writes a linked data API object and its references to the caching
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON data to be written to the cache;
      #   if omitted, this is read from the API
      # @return [void]
      def write_data(entry, urls, data = nil)
        # Read the linked data and associated JSON API data into the cache
        linked_data, json_data = write_object(entry, urls, data)
        if linked_data && entry.references?
          # Start processing this URL
          entry.mark
          # Write the related linked data objects to the cache
          write_related(entry, urls, linked_data)
          # Write the referenced API objects to the cache
          write_references(entry, linked_data)
          # Finish processing this URL
          entry.unmark
        end
        # Return the linked data and JSON API objects
        [linked_data, json_data]
      end

      # Caches a linked data API object and any associated JSON API object
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON linked data of the object; if
      #   omitted, the data is read from the API URL
      # @return [Array] the unparsed and parsed linked data of the object
      def write_object(entry, urls, data = nil)
        # Get the linked data object
        if data
          cache.write(data: data, entry: entry)
        elsif flags[:cacheable]
          data = cache.read(entry: entry)
        end
        # Get the JSON API object if available
        json = cache.read(entry: entry, json: true)
        # Update the set of handled URLs
        urls[entry.url] = true
        # Return the object data
        [data, json]
      end

      # Caches all the objects referenced by the argument object
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   caching operation
      # @param data [Hash] the parsed linked data object
      # @return [void]
      def write_references(urls, data)
        # Cache every URI referenced by this object
        # data.each do |_url, object|
        #   object.each do |_key, values|
        #     values = values.is_a?(Array) ? values : [values]
        #     values.each do |v|
        #       write(v['value'], urls) if v && v['value']
        #     end
        #   end
        # end
        hooks = {
          # Filter non-URI
          pre_hash: proc do |hash, _yielder, _index|
            if hash['type'] == 'uri' && hash['value'] && !hash['value'].empty?
              write(hash['value'], urls)
              false
            else
              true
            end
          end
        }
        data.each do |url, object|
          json_enumerator(url, object, **hooks).each { |_k, _v, _i| }
        end
      end

      # Caches related linked data API objects included with the primary object
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash] the parsed linked data API object
      # @return [void]
      def write_related(entry, urls, data)
        # Write additional related objects to the cache
        data.each do |related_url, related_data|
          write(related_url, urls, related_data) unless entry.url == related_url
        end
      end

      # Returns true if the URL should be written to the cache, false if not
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param nested [Boolean] if
      # @return [Boolean] true if the URL should be written to the cache, false
      #   if not
      def write?(entry, urls, nested)
        # The URL must not have been previously handled
        return false if urls.include?(entry.url)
        # Do not cache lists referenced from other objects
        # (this is to prevent unrelated lists being downloaded through paths
        # such as list.usedBy -> module.usesList -> [unrelated lists])
        return false if nested && list_url?(parsed: entry.parsed_url)
        true
      end
    end
  end
end