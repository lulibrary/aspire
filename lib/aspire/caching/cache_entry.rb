require 'aspire/caching/util'
require 'aspire/exceptions'
require 'aspire/util'

module Aspire
  module Caching
    # Represents an entry in the cache
    class CacheEntry
      include Aspire::Caching::Util
      include Aspire::Exceptions
      include Aspire::Util

      # @!attribute [rw] cache
      #   @return [Aspire::Caching::Cache] the cache
      attr_accessor :cache

      # :!attribute [rw] draft
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

      # Initialises a new CacheEntry instance
      # @param url [String] the URL of the API object
      # @param cache [Aspire::Caching::Cache] the parent cache
      # @return [void]
      # @raise [Aspire::Exceptions::NotCacheable] if the URL is not
      #   cacheable
      def initialize(url, cache)
        self.cache = cache
        self.url = url
      end

      # Returns true if cache entries refer to the same object
      # @param other [Aspire::Caching::CacheEntry, String] a cache entry or URL
      # @return [Boolean] true if the entries refer to the same object
      def ==(other)
        url == url_for_comparison(other, cache.ld_api)
      end

      # Returns true if this cache entry is a child of the URL
      # @param url [Aspire::Caching::CacheEntry, String] the URL to test
      # @param strict [Boolean] if true, the URL must be a parent of this entry,
      #   otherwise the URL must be a parent or the same as this entry
      # @return [Boolean] true if the URL is a child of the cache entry, false
      #   otherwise
      def child_of?(url, strict: false)
        child_url?(parsed_url, url, cache.ld_api, strict: strict)
      end

      # Returns true if the object is in the cache, false if not
      # @return [Boolean] true if the object is cached, false if not
      def cached?(json = false)
        filename = json ? json_file : file
        filename.nil? ? nil : File.exist?(filename)
      end

      # Deletes the object from the cache
      # @param force [Boolean] delete even if the entry is marked in-progress
      # @param remove_children [Boolean] if true, remove children of the object
      #   as well as the object, otherwise remove just the object
      # @return [void]
      # @raise [Aspire::Exceptions::MarkedError] if the entry is
      #   marked in-progress and force = false
      def delete(force: false, remove_children: false)
        mark(force: force) { |_f| delete_entry(file, remove_children) }
      end

      # Returns the linked data filename in the cache
      # @return [String] the linked data filename in the cache
      def file
        File.join(cache.path, url_path)
      end

      # Returns true if the object has associated JSON API data, false if not
      # @return [Boolean] true if the object has associated JSON API data, false
      #   otherwise
      def json?
        !json_api_url.nil? && !json_api_url.empty?
      end

      # Returns the JSON API data filename in the cache or nil if there is no
      # JSON API data for the URL
      # @param filename [String] the linked data filename in the cache
      # @return [String, nil] the JSON API data filename or nil if there is no
      #   JSON API data for the URL
      def json_file(filename = nil)
        json? ? add_filename_suffix(filename || file, '-json') : nil
      end

      # Returns true if the cache entry is a list, false otherwise
      # @param strict [Boolean] if true, the cache entry must be a list,
      #   otherwise the cache entry must be a list or a child of a list
      # @return [Boolean] true if the cache entry is a list, false otherwise
      def list?(strict: true)
        # The cache entry must be a list or the child of a list
        return false unless parsed_url[:type] == 'lists'
        # Strict checking requires that the cache entry is a list, not a child
        return false if strict && !parsed_url[:child_type].nil?
        true
      end

      # Marks the cache entry as in-progress
      # @param force [Boolean] if true, do not raise MarkedError when the entry
      #   is already marked; otherwise, MarkedError is raised when the entry is
      #   already marked.
      # @return [void]
      # @yield [file] passes the opened status file to the block
      # @yieldparam file [File] the opened status file
      # @raise [Aspire::Exceptions::MarkError] if the operation failed
      # @raise [Aspire::Exceptions::MarkedError] if the cache entry is
      #   already marked
      def mark(force: false, &block)
        filename = status_file
        flags = File::CREAT
        flags |= File::EXCL unless force
        File.open(filename, flags, &block)
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

      # Returns true if this cache entry is the parent of the URL
      # @param url [Aspire::Caching::CacheEntry, String] the URL to test
      # @param strict [Boolean] if true, the URL must be a parent of this entry,
      #   otherwise the URL must be a parent or the same as this entry
      # @return [Boolean] true if this cache entry is the parent of the URL,
      #   false otherwise
      def parent_of?(url, strict: false)
        parent_url?(parsed_url, url, cache.ld_api, strict: strict)
      end

      # Returns the filename of the cache entry
      # @param json [Boolean] if true, returns the JSON API filename, otherwise
      #   returns the linked data API filename
      def path(json = false)
        json ? json_file : file
      end

      # Returns data from the cache
      # @param json [Boolean] if true, read the JSON API file, otherwise read
      #   the linked data API file
      # @param parsed [Boolean] if true, return JSON-parsed data, otherwise
      #   return a JSON string
      # @return [Array, Hash, String, nil] the parsed JSON data or JSON string,
      #   or nil if JSON API data is requested but not available for this entry
      # @raise [Aspire::Exceptions::CacheMiss] when the data is not in the cache
      # @raise [Aspire::Exceptions::ReadError] when the read operation fails
      def read(json = false, parsed: false)
        filename = json ? json_file : file
        return nil if filename.nil? || filename.empty?
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

      # Returns a string representation of the cache entry
      # @return [String] the string representation (URL) of the cache entry
      def to_s
        url
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
      # @raise [Aspire::Exceptions::NotCacheable] if the URL is not
      #   cacheable
      def url=(u)
        # Convert the URL to canonical form for comparison
        u = cache.canonical_url(u)
        # Parse and check the URL
        # - this will raise NotCacheable if it is not a valid cacheable URL
        self.parsed_url = cacheable_url(u)
        # Set the URL properties
        @url = u
        return unless list_url?(parsed: parsed_url)
        self.json_api_opt = { bookjacket: 1, editions: 1, draft: 1, history: 1 }
        self.json_api_url = "lists/#{strip_ext(parsed_url[:id])}"
      end

      # Writes data to the cache
      # @param data [Object] the data to write to the cache
      # @param json [Boolean] if true, write the data as JSON API data,
      #   otherwise write it as linked data
      # @param parsed [Boolean] if true, treat data as a parsed JSON data
      #   structure, otherwise treat it as a JSON string
      # @return [void]
      # @raise [Aspire::Exceptions::WriteError] when the write operation fails
      def write(data, json = false, parsed: false)
        filename = json ? json_file : file
        return if filename.nil? || filename.empty?
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

      # Deletes children of the cache entry
      # @param filename [String] the linked data API filename
      # @return [nil]
      # @raise [Aspire::Exceptions::RemoveError] if the operation fails
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
      # @raise [Aspire::Exceptions::RemoveError] if the delete fails
      #   for any reason other than the file not existing
      def delete_file(filename)
        File.delete(filename) unless filename.nil? || filename.empty?
      rescue Errno::ENOENT
        # Ignore file-does-not-exist errors
        nil
      rescue SystemCallError => e
        raise RemoveError, "#{url} remove failed [#{filename}]: #{e}"
      end
    end
  end
end