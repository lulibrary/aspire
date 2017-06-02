require 'aspire/caching/exceptions'
require 'aspire/util'

module Aspire
  module Caching
    # Represents an entry in the cache
    class CacheEntry
      include Aspire::Caching::Exceptions
      include Aspire::Util

      # Rules for determining whether an object URL is cacheable
      # Each rule is a Proc which accepts a parsed URL from #parse_url and the
      # CacheEntry instance, and returns true if the object is cacheable or
      # false if not. Rules are applied in the order specified and all rules
      # must return true for an object to be cacheable.
      CACHEABLE = [
        # The URL must be set and the host must mach the canonical tenancy host
        proc { |u, e| u && e.cache.tenancy_host == t },
        # Catalog objects are not cacheable
        proc { |u, _e| u[:type] != 'catalog' },
        # User objects themselves are not cacheable but child objects e.g. notes
        # are cacheable
        proc { |u, _e| u[:type] != 'users' || !u[:child_type].nil? },
        # Importance URI values are not cacheable
        proc do |u, _e|
          u[:type] != 'config' || !u[:uri].to_s.start_with?('importance')
        end
      ].freeze

      # @!attribute [rw] cache
      #   @return [Aspire::Caching::Cache] the cache
      attr_accessor :cache

      # @!attribute [rw] json_api_opt
      #   @return [Hash] #call parameters for the JSON API call
      attr_accessor :json_api_opt

      # @!attribute [rw] json_api_url
      #   @return [String] the JSON API #call URL
      attr_accessor :json_api_url

      # @!attribute [rw] uri
      #   @return [MatchData] the parsed URL
      attr_accessor :parsed_url

      # @!attribute [rw] url
      #   @return [String] the URL
      attr_accessor :url

      # Returns true if the URL is cacheable, false if not
      # @param u [String] the URL of the API object
      # @return [Boolean] true if the URL is cacheable, false if not
      def self.cacheable?(u)
        cacheable_url(u).nil? ? false : true
      rescue NotCacheable
        false
      end

      # Initialises a new CacheEntry instance
      # @param url [String] the URL of the API object
      # @param cache [Aspire::Caching::Cache] the parent cache
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::NotCacheable] if the URL is not
      #   cacheable
      def initialize(url, cache)
        self.cache = cache
        self.url = url
      end

      # Returns true if the object is in the cache, false if not
      # @return [Boolean] true if the object is cached, false if not
      def cached?
        File.exist?(file)
      end

      # Deletes the object from the cache
      # @param force [Boolean] delete even if the entry is marked in-progress
      # @param remove_children [Boolean] if true, remove children of the object
      #   as well as the object, otherwise remove just the object
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::MarkedError] if the entry is
      #   marked in-progress and force = false
      def delete(force: false, remove_children: false)
        mark { |_f| delete_entry(file, remove_children) }
      rescue MarkedError
        # Raise the exception if not forcing the deletion
        raise unless force
        # Otherwise unmark the file and retry
        unmark
        force = false # If the retry fails, raise the exception
        retry
      end

      # Returns the linked data filename in the cache
      # @return [String] the linked data filename in the cache
      def file
        File.join(cache.path, url_path)
      end

      # Returns true if the object has cached JSON API data, false if not
      # @return [Boolean] true if the object has cached JSON API data, false
      #   if the object has no associated JSON API data or the data is not
      #   cached
      def json?
        filename = json_file
        !filename.nil? && File.exist?(filename)
      end

      # Returns the JSON API data filename in the cache
      # @param filename [String] the linked data filename in the cache
      def json_file(filename = nil)
        json? ? add_filename_suffix(filename || file) : nil
      end

      # Marks the cache entry as in-progress
      # @return [void]
      # @yield [file] passes the opened status file to the block
      # @yieldparam file [File] the opened status file
      # @raise [Aspire::Caching::Exceptions::MarkError] if the operation failed
      # @raise [Aspire::Caching::Exceptions::MarkedError] if the cache entry is
      #   already marked
      def mark(&block)
        filename = status_file
        File.open(filename, File::CREAT | File::EXCL, &block)
      rescue Errno::EEXIST
        raise MarkedError, "#{url} already marked [#{filename}]"
      rescue SystemCallError => e
        raise MarkError, "#{url} mark failed [#{filename}]: #{e}"
      end

      # Returns true if the cache entry is locked
      # @return [Boolean] true if the cache entry is marked as in-progress,
      #   false otherwise
      def marked?
        File.exist?(status_file)
      end

      # Returns the filename of the cache entry
      # @param json [Boolean] if true, returns the JSON API filename, otherwise
      #   returns the linked data API filename
      def path(json = false)
        json ? json_file : file
      end

      # Returns data from the cache
      def read(json = false, parsed: false)
        filename = json ? file : json_file
        File.open(filename, 'r') do |f|
          data = f.read
          return parsed ? JSON.parse(data) : data
        end
      rescue Errno::ENOENT
        raise CacheMiss, "#{url} cache miss [#{filename}"
      rescue IOError, SystemCallError => e
        raise ReadError, "#{url} cache read failed [#{filename}]: #{e}"
      end

      # Returns true if the object's references are cacheable
      # @return [Boolean] true if the object's references are cacheable, false
      #   otherwise
      def references?
        # Events are not JSON-LD so we can't cache references
        parsed_url[:type] != 'events' && parsed_url[:child_type] != 'events'
      end

      # Returns the status filename in the cache
      # @param filename [String] the linked data filename in the cache
      def status_file(filename = nil)
        # Prepend '.' to the filename
        add_filename_prefix(filename || file, '.')
      end

      # Removes an in-progress mark from the cache entry
      def unmark
        filename = status_file
        File.delete(filename) if File.exist?(filename)
      rescue SystemCallError => e
        raise UnmarkError, "#{url} unmark failed [#{filename}]: #{e}"
      end

      # Sets the URL and associated flags
      # @param u [String] the URL of the API object
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::NotCacheable] if the URL is not
      #   cacheable
      def url=(u)
        self.parsed_url = cacheable_url(u)
        @url = u
        # Derive the remaining properties from the URL
        return unless list_url?(parsed: u)
        self.json_api_opt = { bookjacket: 1, editions: 1, draft: 1, history: 1 }
        self.json_api_url = "lists/#{strip_ext(parsed_url[:id])}"
      end

      # Writes data to the cache
      # @param data [Object] the data to write to the cache
      # @param json [Boolean] if true, write the data as JSON API data,
      #   otherwise write it as linked data
      # @param parsed [Boolean] if true, treat data as a parsed JSON data
      #   structure, otherwise treat it as a JSON string
      def write(data, json = false, parsed: false)
        filename = json ? json_file : file
        # Create the path to the file
        FileUtils.mkdir_p(File.dirname(filename), mode: cache.mode)
        # Write the data
        File.open(filename, 'w') do |f|
          f.flock(File::LOCK_EX)
          f.write(parsed ? JSON.generate(data) : data)
        end
      rescue IOError, JSON::JSONError, SystemCallError => e
        raise WriteError, "#{url} cache write failed [#{filename}]: #{e}"
      end

      private

      # Parses the URL and checks that it is cacheable
      # @param u [String] the URL of the API object
      # @return [MarchData] the parsed URL
      # @raise [Aspire::Caching::Exceptions::NotCacheable] if the URL is not
      #   cacheable
      def cacheable_url(u)
        # All rules must return true for the URL to be cacheable
        u = parse_url(u)
        CACHEABLE.each { |r| raise NotCacheable unless r.call(u, self) }
        # Return the parsed URL
        u
      end

      # Deletes children of the cache entry
      # @param filename [String] the linked data API filename
      # @return [nil]
      # @raise [Aspire::Caching::Exceptions::RemoveError] if the operation fails
      def delete_children(filename)
        # Child objects of the cache entry are stored in a directory with the
        # same name as the linked data cache file without the '.json' extension
        children = "#{strip_ext(filename)}/*"
        return unless children.nil? || children.empty? || children == '/*'
        FileUtils.rm_rf(Dir.glob(children), secure: true)
      rescue SystemCallError => e
        raise RemoveError, "#{url} remove failed [#{children}]: #{e}"
      end

      # Deletes the files for the cache entry and removes any empty directories
      # on the cache file's path
      # @param filename [String] the linked data filename in the cache
      # @param remove_children [Boolean]
      # @return [nil]
      def delete_entry(filename, remove_children = false)
        # Delete the files for the cache entry
        delete_file(filename)
        delete_file(json_file(filename))
        delete_file(status_file(filename))
        delete_children(filename) if remove_children
        # Delete any empty directories on the entry's file path
        rmdir_empty(filename, cache.path)
      end

      # Deletes the specified file
      # @param filename [String] the filename to delete
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::RemoveError] if the delete fails
      #   for any reason other than the file not existing
      def delete_file(filename)
        File.delete(filename) unless filename.nil? || filename.empty?
        nil
      rescue Errno::ENOENT
        # Ignore file-does-not-exist errors
        nil
      rescue SystemCallError => e
        raise RemoveError, "#{url} remove failed [#{filename}]: #{e}"
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
    end
  end
end