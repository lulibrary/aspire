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
      def initialize(cache, users: nil)
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
        # Get item data from the parent list's JSON API data
        return ListItem.new(uri, self, parent) if uri.include?('/items/')
        # Get resource data from the JSON API
        if uri.include?('/resources/') && !json.nil?
          return Resource.new(uri, self, json: json, ld: ld)
        end
        # Get user data from the users lookup table
        return users[uri] if uri.include?('/users/')
        # Get lists, modules, resources and sections from the Linked Data API
        get_linked_data(uri, parent, json: json, ld: ld)
      end

      def get_linked_data(uri, parent = nil, json: nil, ld: nil)
        ld ||= cache.read(uri)
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