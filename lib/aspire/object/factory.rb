require 'aspire/object/list'
require 'aspire/object/module'
require 'aspire/object/resource'
require 'aspire/util'

module Aspire
  module Object
    # A factory returning reading list objects given the object's URI
    class Factory
      include Aspire::Util

      # @!attribute [rw] cache
      #   @return [Aspire::Caching::Cache] the cache for retrieving data
      attr_accessor :cache

      # @!attribute [rw] users
      #   @return [Hash<String, Aspire::Object::User>] a hash of user profiles
      #     indexed by URI
      attr_accessor :users

      # Initialises a new ReadingListFactory instance
      # @param cache  [Aspire::Caching::Cache] the cache for retrieving data
      # @param users [Hash<String, Aspire::Object::User>] a hash of user
      #   profiles indexed by URI
      # @return [void]
      def initialize(cache, users = nil)
        self.cache = cache
        self.users = users || {}
      end

      # Returns a new API list object (Aspire::Object::ListBase subclass) given
      # its URI
      # @param uri [String] the URI of the object
      # @param parent [Aspire::Object::ListBase] this object's parent object
      # @param json [Hash] the parsed JSON API data for the object
      # @param ld [Hash] the parsed linked data API data for the object
      # @return [Aspire::Object::ListBase] the list object
      def get(uri = nil, parent = nil, json: nil, ld: nil)
        return nil if uri.nil? || uri.empty?
        get_exceptions(uri, parent, json: json, ld: ld) ||
          get_linked_data(uri, parent, json: json, ld: ld)
      end

      private

      # Returns a new object from sources other than the linked data API
      # @param uri [String] the URI of the object
      # @param parent [Aspire::Object::ListBase] this object's parent object
      # @param json [Hash] the parsed JSON API data for the object
      # @param ld [Hash] the parsed linked data API data for the object
      # @return [Aspire::Object::ListBase, nil] the list object or nil if not
      #   available
      def get_exceptions(uri = nil, parent = nil, json: nil, ld: nil)
        # Get item data from the parent list's JSON API data
        return ListItem.new(uri, self, parent) if item?(uri)
        # Get resource data from the JSON API
        if resource?(uri) && !json.nil?
          return Resource.new(uri, self, json: json, ld: ld)
        end
        # Get user data from the users lookup table
        # - normalise the URI to the form used by the linked data API
        return users[cache.linked_data_url(uri), self] if user?(uri)
        # Otherwise no exceptions
        nil
      end

      # Returns a new object from the linked data API
      # @param uri [String] the URI of the object
      # @param parent [Aspire::Object::ListBase] this object's parent object
      # @param json [Hash] the parsed JSON API data for the object
      # @param ld [Hash] the parsed linked data API data for the object
      # @return [Aspire::Object::ListBase, nil] the list object or nil if not
      #   available
      def get_linked_data(uri, parent = nil, json: nil, ld: nil)
        # Call #linked_data to determine whether uri is present in ld
        ld = linked_data(uri, ld) || cache.read(uri)
        return List.new(uri, self, parent, json: json, ld: ld) if list?(uri)
        return Module.new(uri, self, json: json, ld: ld) if module?(uri)
        return Resource.new(uri, self, json: json, ld: ld) if resource?(uri)
        if section?(uri)
          return ListSection.new(uri, self, parent, json: json, ld: ld)
        end
        nil
      end
    end
  end
end