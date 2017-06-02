module Aspire
  # Utility methods mixin
  module Util
    # Regular expression to parse a Linked Data API URI
    LD_API_URI = Regexp.new('https?://(?<tenancy_host>[^/]*)/' \
                            '(?<type>[^/]*)/' \
                            '(?<id>[^/]*)' \
                            '(/' \
                            '(?<child_type>[^/]*)' \
                            '(/(?<child_id>[^/]*))?' \
                            ')?').freeze

    # Returns the ID of an object from its URL
    # @param u [String] the URL of the API object
    # @return [String] the object ID
    def id_from_uri(u, parsed: nil)
      parsed ||= parse_url(u)
      parsed[:id]
    end

    # Enumerates the property/value pairs of a JSON data structure
    # @param key [String] the property name
    # @param value [Object] the property value
    # @param yielder [Enumerator::Yielder] the yielder from the Enumerator
    # @param hooks [Hash] the callback hooks
    # @param index [Integer] the index of the property in its parent array, or
    #   nil if not part of an array
    # @return [void]
    def json_enum(key, value, yielder, hooks = nil, index = nil)
      if value.is_a?(Array)
        json_enum_array(key, value, yielder, hooks)
      elsif value.is_a?(Hash)
        json_enum_hash(value, yielder, hooks)
      else
        json_enum_yield(key, value, yielder, hooks, index)
      end
    end

    # Enumerates an array of JSON data structures
    # @param key [String] the property name
    # @param array [Object] the property value
    # @param yielder [Enumerator::Yielder] the yielder from the Enumerator
    # @return [void]
    def json_enum_array(key, array, yielder, hooks = nil)
      return unless json_enum_hook(:pre_array, hooks, key, array, yielder)
      i = 0
      array.each do |value|
        json_enum(key, value, yielder, hooks, i)
        i += 1
      end
      json_enum_hook(:post_array, hooks, key, array, yielder, i)
    end

    # Enumerates the property/value pairs of a JSON hash
    # @param hash [Hash] the hash to enumerate
    # @param yielder [Enumerator::Yielder] the yielder from the Enumerator
    # @param index [Integer] the index of the property in its parent array, or
    #   nil if not part of an array
    # @return [void]
    def json_enum_hash(hash, yielder, hooks = nil, index = nil)
      return unless json_enum_hook(:pre_hash, hooks, hash, yielder, index)
      hash.each do |key, value|
        if value.is_a?(Array) || value.is_a?(Hash)
          json_enum(key, value, yielder, hooks)
        else
          json_enum_yield(key, value, yielder, hooks, index)
        end
      end
      json_enum_hook(:post_hash, hooks, hash, yielder, index)
    end

    # Runs a JSON enumeration hook
    # @param hook [Symbol] the hook name
    # @param hooks [Hash] the hook definitions
    # @return [Boolean] true if the hook returns a true value, false otherwise
    def json_enum_hook(hook, hooks = nil, *args, **kwargs)
      # Return true on invalid hooks to allow processing to continue
      return true unless hooks && hooks[hook] && hooks[hook].respond_to?(:call)
      # Call the hook
      hooks[hook].call(*args, **kwargs) ? true : false
    end

    # Enumerates the property/value pairs of a JSON data structure
    # @param key [String] the property name
    # @param value [Object] the property value
    # @param yielder [Enumerator::Yielder] the yielder from the Enumerator
    # @param hooks [Hash] the callback hooks
    # @param index [Integer] the index of the property in its parent array, or
    #   nil if not part of an array
    # @return [void]
    def json_enum_yield(key, value, yielder, hooks = nil, index = nil)
      return unless json_enum_hook(:before_yield, hooks, key, value, index)
      yielder << [key, value, index]
      json_enum_hook(:after_yield, hooks, key, value, index)
    end

    # Returns an enumerator enumerating property/value pairs of JSON data
    # @param key [String] the initial key of the data
    # @param value [Object] the initial value of the data
    # @param hooks [Hash] processing callback hooks
    #   { after_array: proc { |key, array, yielder, index| },
    #     after_hash: proc  { |array, yielder, index| },
    #     after_yield: proc { |key, value, yielder, index| },
    #     before_array: proc { |key, array, yielder, index| },
    #     before_hash: proc { |array, yielder, index| },
    #     before_yield: proc { |key, array, yielder, index| }
    #   }
    # @return [Enumerator] the JSON enumerator
    def json_enumerator(key, value, **hooks)
      Enumerator.new { |yielder| json_enum(key, value, yielder, hooks) }
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

    # Returns a file path from a URL path
    # @param u [String] the URL of the API object
    # @param file_root [String] the root of the file path
    # @return [String] the file path
    def url_to_path(url, file_root)
      # Get the path component of the URL as a relative path
      path = URI.parse(url).path
      path.slice!(0)
      # Prepend the filesystem root path to the relative URL path
      path = File.join(file_root, path)
      # Add '.json' extension if not already present
      ext = File.extname(path)
      path = "#{path}.json" if ext.nil? || ext.empty?
      # Return the filesystem path
      path
    rescue URI::InvalidComponentError, URI::InvalidURIError
      # Return nil if the URL is invalid
      nil
    end
  end
end