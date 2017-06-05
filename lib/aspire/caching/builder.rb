require 'benchmark'
require 'json'
require 'logger'
require 'uri'

require 'aspire/caching/cache_entry'
require 'aspire/caching/cache_logger'
require 'aspire/caching/enumerator'
require 'aspire/caching/exceptions'
require 'aspire/caching/util'

module Aspire
  # Tools for building a cache from the Aspire APIs
  module Caching
    # Caches Aspire API objects and their references
    class Builder
      include Exceptions
      include Util

      # @!attribute [rw] cache
      #   @return [Aspire::Caching::Cache] the Aspire cache
      attr_accessor :cache

      # Initialises a new Cache instance
      # @param cache [Aspire::Caching::Cache] the Aspire cache
      # @return [void]
      def initialize(cache = nil)
        self.cache = cache
      end

      # Builds a cache of Aspire lists from the Aspire All Lists report
      # @param enumerator [Aspire::Enumerator::ListReportEnumerator] the Aspire
      #   All Lists report enumerator
      # @param clear [Boolean] if true, clear the cache before building
      # @return [Integer] the number of lists cached
      def build(enumerator, clear: false)
        # Empty the cache if required
        cache.clear if clear
        # Cache the enumerated lists
        # - call with reload: false so that existing cache entries are ignored
        #   to speed up processing
        lists = 0
        time = Benchmark.measure do
          enumerator.each do |row|
            write_list(row['List Link'], reload: false)
            lists += 1
          end
        end
        # Log completion
        cache.logger.log(Logger::INFO,
                         "#{lists} lists cached in #{duration(time)}")
      end

      # Caches an Aspire linked data API object.
      #    Use write(url) to build a cache for the first time.
      #    Use write(url, reload: true) to reload parts of the cache.
      # @param url [String] the URL of the API object
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON data to be written to the cache;
      #   if omitted, this is read from the API
      # @param list [Aspire::Caching::CacheEntry] the parent list cache entry;
      #   if present, this implies that references to other lists are ignored
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [void]
      def write(url = nil, urls = {}, data = nil, list: nil, reload: true)
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
        entry = url.nil? ? list : CacheEntry.new(url, cache)
        return unless entry && write?(entry, urls, list, reload)
        write_data(entry, urls, data, list, reload)
      rescue NotCacheable
        nil
      end

      # Caches an Aspire linked data API list object and ignores any references
      # to other lists
      # @param url [String] the URL of the API list object
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON data to be written to the cache;
      #   if omitted, this is read from the API
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [void]
      def write_list(url = nil, urls = {}, data = nil, reload: true)
        entry = CacheEntry.new(url, cache)
        raise ArgumentError, 'List expected' unless entry.list?
        write(url, urls, data, list: entry, reload: reload)
      rescue NotCacheable
        nil
      end

      private

      # Returns true if the entry is already cached and should be skipped
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param reload [Boolean] If true, do not skip cached entries and reload
      #   from the API. Otherwise, cached entries are skipped
      def already_cached?(entry, reload)
        if reload
          # Ignore any in-progress marker and do not skip
          entry.unmark if entry.marked?
          false
        else
          # Cached entries will be skipped
          entry.cached?
        end
      end

      # Returns true if the cache entry is a list which is unrelated to the
      # parent list. This prevents unrelated lists being downloaded through
      # paths such as list.usedBy -> module.usesList -> [unrelated lists]).
      # Returns false if:
      #   no parent list is provided,
      #   or the cache entry is not a list,
      #   or it is the same as the parent list,
      #   or it is a child of the parent list.
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param parent_list [Aspire::Caching::CacheEntry] the parent list entry
      # @return [Boolean] true if the cache entry is a list unrelated to the
      #   parent list, otherwise false
      def unrelated_list?(entry, parent_list)
        # Ignore if no parent list is given or the entry is not a list/child
        return false unless parent_list
        # Ignore if the entry is not a list
        return false unless entry.list?(strict: false)
        # Ignore if the entry is a child of (or the same as) the parent list
        return false if entry.child_of?(parent_list, strict: false)
        # Otherwise the entry is a list unrelated to the parent list
        true
      end

      # Writes a linked data API object and its references to the caching
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash, nil] the parsed JSON data to be written to the cache;
      #   if omitted, this is read from the API
      # @param parent_list [Aspire::Caching::CacheEntry] the parent list entry
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [void]
      def write_data(entry, urls, data = nil, parent_list = nil, reload = true)
        # Read the linked data and associated JSON API data into the cache
        linked_data, json_data = write_object(entry, urls, data, reload)
        if linked_data && entry.references?
          # Start processing this URL
          entry.mark
          # Write the related linked data objects to the cache
          write_related(entry, urls, linked_data, parent_list, reload)
          # Write the referenced API objects to the cache
          write_references(urls, linked_data, parent_list, reload)
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
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [Array] the unparsed and parsed linked data of the object
      def write_object(entry, urls, data = nil, reload = true)
        # Ignore the cache if reloading
        use_cache = !reload
        # Get the linked data object
        data = write_object_data(entry, data, use_cache)
        # Get the JSON API object if available
        json = write_object_json(entry, use_cache)
        # Update the set of handled URLs
        #urls[entry.url] = true
        # Return the object data
        [data, json]
      end

      # Writes a linked data API object to the cache
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param data [Hash] the data to write to the cache
      # @param use_cache [Boolean] if true, return data from the cache,
      #   otherwise update the cache with data from the API
      def write_object_data(entry, data, use_cache)
        if data
          cache.write(data: data, entry: entry)
        else
          cache.read(entry: entry, use_cache: use_cache)
        end
      end

      # Writes a JSON API object to the cache
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param use_cache [Boolean] if true, return data from the cache,
      #   otherwise update the cache with data from the API
      def write_object_json(entry, use_cache)
        return nil unless entry.json?
        cache.read(entry: entry, json: true, use_cache: use_cache)
      end

      # Caches all the objects referenced by the argument object
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   caching operation
      # @param data [Hash] the parsed linked data object
      # @param parent_list [Aspire::Caching::CacheEntry] the parent list entry
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [void]
      def write_references(urls, data, parent_list = nil, reload = true)
        data.each do |url, object|
          # Write each URI to the cache
          references(url, object).each do |uri|
            write(uri, urls, list: parent_list, reload: reload)
          end
        end
      end

      # Caches related linked data API objects included with the primary object
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param data [Hash] the parsed linked data API object
      # @param parent_list [Aspire::Caching::CacheEntry] the parent list entry
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [void]
      def write_related(entry, urls, data, parent_list = nil, reload = true)
        # Write all related objects to the cache before caching references
        data.each do |related_url, related_data|
          # The main cache entry should already have been written
          next if entry.url == cache.canonical_url(related_url)
          write(related_url, urls, list: parent_list, reload: reload)
        end
      end

      # Returns true if the URL should be written to the cache, false if not
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param urls [Hash] the set of previously-handled URLs in the current
      #   cache operation
      # @param parent_list [Aspire::Caching::CacheEntry] the parent list entry
      # @param reload [Boolean] if true, reload the cache entry from the API,
      #   otherwise do nothing if the entry is already in the cache
      # @return [Boolean] true if the URL should be written to the cache, false
      #   if not
      def write?(entry, urls, parent_list = nil, reload = true)
        return false if already_cached?(entry, reload)
        return false if unrelated_list?(entry, parent_list)
        # The URL must not have been previously handled
        # return false if urls.include?(entry.url)
        true
      end
    end
  end
end