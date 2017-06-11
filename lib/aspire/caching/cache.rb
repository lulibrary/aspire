require 'aspire/caching/cache_entry'
require 'aspire/caching/exceptions'
require 'aspire/caching/util'

module Aspire
  module Caching
    # Reads and writes Aspire API data to and from a file-based cache
    class Cache
      include Exceptions
      include Util

      # The default cache directory permissions
      MODE = 0o0750

      # The default cache root directory
      PATH = '/tmp/aspire/cache'.freeze

      # @!attribute [rw] json_api
      #   @return [Aspire::API::JSON] the JSON API instance
      attr_accessor :json_api

      # @!attribute [rw] ld_api
      #   @return [Aspire::API::LinkedData] the linked data API instance
      attr_accessor :ld_api

      # @!attribute [rw] logger
      #   @return [Aspire::Caching::CacheLogger] the cache activity logger
      attr_accessor :logger

      # @!attribute [rw] mode
      #   @return [String, Integer] the cache directory permissions
      attr_accessor :mode

      # @!attribute [rw] path
      #   @return [String] the cache root directory
      attr_accessor :path

      # Initialises a new Cache instance
      # @param json_api [Aspire::API::JSON] the JSON API instance
      # @param ld_api [Aspire::API::LinkedData] the linked data API instance
      # @param path [String] the cache root directory
      # @param options [Hash] the cache options
      # @option options [Integer] :api_retries the maximum number of retries
      #   after an API call timeout
      # @option options [Boolean] :clear if true, clear the cache, otherwise
      #   leave any existing cache content intact
      # @option options [Logger] :logger the cache activity logger
      # @option options [String, Integer] :mode the cache directory permissions
      # @return [void]
      def initialize(ld_api = nil, json_api = nil, path = nil, **options)
        options ||= {}
        self.json_api = json_api
        self.ld_api = ld_api
        self.logger = Aspire::Caching::CacheLogger.new(options[:logger])
        self.mode = options[:mode] || MODE
        self.path = path || PATH
        # Clear the cache contents if required
        clear if options[:clear]
      end

      # Returns a CacheEntry instance for the URL
      # @param url [String] the URL of the API object
      # @return [Aspire::Caching::CacheEntry] the cache entry
      def cache_entry(url)
        CacheEntry.new(ld_api.canonical_url(url), self)
      end

      # Returns the canonical form of the URL
      # @param url [String] the URL of the API object
      # @return [String] the canonical URL of the object
      def canonical_url(url)
        ld_api.canonical_url(url)
      end

      # Clears the cache contents
      # @return [void]
      # @raise [Aspire::Cache::Exceptions::RemoveError] if the operation fails
      def clear
        return unless path?
        rm(File.join(path, '*'), logger, 'Cache cleared', 'Cache clear failed')
      end

      # Deletes the cache
      # @return [void]
      # @raise [Aspire::Cache::Exceptions::RemoveError] if the operation fails
      def delete
        return unless path?
        rm(path, logger, 'Cache deleted', 'Cache delete failed')
      end

      # Returns true if the cache is empty, false if not
      # @return [Boolean] true if the cache is empty, false if not
      def empty?
        Dir.empty?(path)
      end

      # Returns true if the specified URL is in the cache, false if not
      # @param url [String] the URL
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @return [Boolean] true if the URL is in the cache, false if not
      def include?(url = nil, entry: nil)
        entry ||= cache_entry(url)
        entry.cached?
      end

      # Iterates over a single cache object type and passes the partial object
      # URLs to the block
      # @param type [String] the cache object type ('lists', 'resources' etc.)
      #   or '**' for all object types
      # @yield [url] passes the partial object URL to the block
      # @yieldparam url [String] the partial object URL of the list
      # @return [void]
      def marked_entry(type)
        Dir.glob(File.join(path, type, '.[^.]*')) do |filename|
          # Convert the filename to a URL and pass to the block
          begin
            entry = CacheEntry.new(filename_to_url(filename), self)
            yield(entry) if block_given?
          rescue NotCacheable
            nil
          end
        end
      end

      # Iterates over marked (in-progress) cache entries and passes the partial
      # URL path to the block
      # Positional parameters are the object types to include, e.g. 'lists',
      # 'resources' etc. - default: all object types
      # @yield [url] passes the list URL to the block
      # @yieldparam url [String] the partial linked data URL of the list
      # @return [void]
      def marked_entries(*types, &block)
        if types.nil? || types.empty?
          marked_entry('**', &block)
        else
          types.each { |type| marked_entry(type, &block) }
        end
      end

      # Sets and creates the root directory of the cache
      # @param dir [String] the root directory path of the cache
      # @return [void]
      # @raise [ArgumentError] if no path is specified
      # @raise [CacheError] if the directory cannot be created
      def path=(dir = nil)
        raise ArgumentError, 'directory expected' if dir.nil? || dir.empty?
        mkdir(dir, logger, "Cache path set to #{dir}", 'Set cache path failed')
        @path = dir
      end

      # Returns true if the cache path is a valid directory
      # @return [Boolean] true if the cache path is a valid directory
      def path?
        !path.nil? && File.directory?(path)
      end

      # Reads an API data object from the cache or API
      # @param url [String] the URL of the API object
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param json [Boolean] if true, read the JSON API, otherwise read the
      #   linked data API
      # @param use_cache [Boolean] if true, try the cache before the Aspire API
      # @yield [data, flags] passes the data and flags to the block
      # @yieldparam data [Hash] the parsed data from the cache or API call
      # @yieldparam flags [Hash] the cache processing flags
      # @yieldparam from_cache [Boolean] true if the data was read from the
      #   cache, false if it was read from the API
      # @yieldparam json [Boolean] true if the data is from the JSON API, false
      #   if it is from the linked data API
      # @return [Hash] the parsed JSON data from the cache or API
      # @raise [Aspire::Cache::Exceptions::]
      def read(url = nil,
               entry: nil, json: false, use_api: true, use_cache: true)
        entry ||= cache_entry(url)
        # Try the cache, data is nil on a cache miss
        data = use_cache ? read_cache(entry, json: json) : nil
        from_cache = !data.nil?
        # Try the API if nothing was returned from the cache
        data ||= write(entry: entry, json: json) if use_api
        # Call the block if the read was successful
        yield(data, entry, from_cache, json) if block_given? && data
        # Return the data
        data
      rescue NotCacheable
        # Uncacheable URLs have no data representation in the Aspire API
        nil
      end

      # Removes the URL from the cache
      # @param url [String] the URL of the API object
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param force [Boolean] if remove, remove the URL even if it is marked
      #   as in-progress; otherwise fails on marked entries
      # @param remove_children [Boolean] if true, remove all children of the
      #   object as well as the object itself, otherwise remove just the object
      # @yield [data, entry] passes the data and cache entry to the block
      # @yieldparam data [Hash] the parsed JSON data from the cache or API call
      # @yieldparam entry [Aspire::Caching::CacheEntry] the cache entry
      # @return [Hash, nil] the parsed JSON data removed from the cache
      # @raise [Aspire::Caching::Exceptions::MarkedError] if the cache entry is
      #   marked as in-progress and force is false
      # @raise [Aspire::Caching::Exceptions::RemoveError] if the operation fails
      def remove(url = nil, entry: nil, force: false, remove_children: false)
        entry ||= cache_entry(url)
        return nil unless entry.cached?
        # Read the data from the cache for the return value
        data = read_cache(entry)
        # Call the block
        yield(data, entry) if block_given?
        # Remove the cached files
        entry.delete(force: force, remove_children: remove_children)
        # Return the cached data
        data
      rescue NotCacheable
        nil
      end

      # Returns the Aspire tenancy host name
      # @return [String] the Aspire tenancy host name
      def tenancy_host
        ld_api ? ld_api.tenancy_host : nil
      end

      # Writes an API object to the cache
      # @param url [String] the URL of the API object
      # @param data [Hash, String, nil] parsed or unparsed data to be cached
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param json [Boolean] if true, read the JSON API, otherwise read the
      #   linked data API
      # @yield [data, entry] passes the data and cache entry to the block
      # @yieldparam data [Hash] the parsed JSON data from the cache or API call
      # @yieldparam entry [Aspire::Caching::CacheEntry] the cache entry
      # @return [Hash] the parsed JSON data written to the cache
      # @raise [Aspire::Caching::Exceptions::WriteError] if the operation fails
      def write(url = nil, data: nil, entry: nil, json: false)
        # Get the cache processing flags
        entry ||= cache_entry(url)
        # Get the data from the API if not supplied
        raw, parsed = write_data(data) || read_api(entry, json: json)
        return nil unless raw && parsed
        # Write the data to the cache
        write_cache(entry, raw, json: json)
        # Call the block
        yield(parsed, entry) if block_given?
        # Return the data written to the cache
        parsed
      end

      private

      # Converts a status filename to a linked data URL
      # @param filename [String] the filename of a linked data object status
      #   file in the cache
      def filename_to_url(filename)
        # Remove the cache path
        f = strip_prefix(filename, path)
        # Remove the leading . from the base filename
        f = strip_filename_prefix(f, '.')
        # Remove the leading / from the path
        f.slice!(0) if f.start_with?('/')
        # Return the full Aspire linked data URL
        ld_api.api_url(f)
      end

      # Reads data from the Aspire JSON or linked data APIs
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param json [Boolean] if true, read the JSON API, otherwise read the
      #   linked data API
      # @return [Array] the unparsed JSON string and parsed hash from the API
      def read_api(entry, json: false)
        data = json ? read_json_api(entry) : read_linked_data_api(entry)
        logger.log(Logger::DEBUG, read_api_msg('read', entry, json))
        data
      rescue APITimeout, APIError => e
        msg = read_api_msg('read failed', entry, json, e)
        logger.log_exception(msg, ReadError)
      end

      # Returns a log/exception message for #read_api
      # @param msg [String] the event message
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param json [Boolean] if true, return a JSON API message, otherwise
      #   return a linked data API message
      # @param exception [Exception] the exception
      # @return [String] the formatted log message
      def read_api_msg(msg, entry, json, exception = nil)
        [
          "#{entry.url} #{msg} from #{json ? 'JSON' : 'LD'} API",
          json ? " [#{entry.json_api_url}]" : '',
          exception ? ": #{exception}" : ''
        ].join
      end

      # Reads an Aspire linked data URL from the cache
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param json [Boolean] if true, read JSON API data, otherwise read
      #   linked data API data
      # @return [Hash, nil] the parsed JSON data from the cache or nil if the
      #   URL is not cached
      # @raise [Aspire::Cache::Exceptions::ReadError] if the cache read fails
      def read_cache(entry, json: false)
        data = entry.read(json, parsed: true)
        msg = "#{entry.url}#{json ? ' [JSON]' : ''} read from cache"
        logger.log(Logger::DEBUG, msg)
        data
      rescue CacheMiss
        nil
      end

      # Reads data from the Aspire JSON API
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @return [Array] the unparsed JSON string and parsed hash from the API
      def read_json_api(entry)
        opts = entry.json_api_opt || {}
        url = entry.json_api_url
        json_api.call(url, **opts) do |response, data|
          return response.body, data
        end
      end

      # Reads data from the Aspire linked data API
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @return [Array] the unparsed JSON string and parsed hash from the API
      def read_linked_data_api(entry)
        ld_api.call(entry.url) { |response, data| return response.body, data }
      end

      # Writes data to the cache
      # @param entry [Aspire::Caching::CacheEntry] the cache entry
      # @param data [String] the data to be written to the cache
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::WriteError] if the operation fails
      def write_cache(entry, data = nil, json: false)
        entry.write(data, json)
        file_path = entry.path(json)
        logger.log(Logger::INFO, "#{entry.url} written to cache [#{file_path}]")
      rescue WriteError => e
        logger.log(Logger::ERROR, e.to_s)
      end

      # Converts user-supplied data to a string for caching
      # @param data [Hash, String] the data to be written to the cache
      # @return [Array, nil] the unparsed JSON string and parsed hash
      def write_data(data = nil)
        # Return nil if no data is supplied
        return nil if data.nil?
        # Return a JSON string and the data if a Hash is supplied
        parsed_json = data.is_a?(Hash) || data.is_a?(Array)
        return JSON.generate(data), data if parsed_json
        # Otherwise return the data as a string and a parsed JSON hash
        data = data.to_s
        [data, JSON.parse(data)]
      end
    end
  end
end