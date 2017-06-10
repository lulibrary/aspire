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
        self.api = api
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
        # Get item data from the parent list (from the JSON API) rather than the Linked Data API
        return ListItem.new(uri, self, parent) if uri.include?('/items/')
        # Get resource data from the JSON API rather than the Linked Data API if available
        return Resource.new(uri, self, json: json, ld: ld) if uri.include?('/resources/') && !json.nil?
        # Get user data from the users hash
        return get_user(uri, ld) if uri.include?('/users/')
        # Get lists, modules, resources and sections from the Linked Data API
        get_linked_data(uri, parent, json: json, ld: ld)
      end

      def get_linked_data(uri, parent = nil, json: nil, ld: nil)
        # If the URI is present in the linked data hash, the corresponding data is used. Otherwise, the data is
        # loaded from the linked data API.
        puts(uri)
        ld = self.api.get_json(uri, expand_path: false) if ld.nil? || !ld.has_key?(uri)
        return List.new(uri, self, parent, json: json, ld: ld) if uri.include?('/lists/')
        return Module.new(uri, self, json: json, ld: ld) if uri.include?('/modules/')
        return Resource.new(uri, self, json: json, ld: ld) if uri.include?('/resources/')
        return ListSection.new(uri, self, parent, json: json, ld: ld) if uri.include?('/sections/')
        nil
      end

      # Returns a new user profile object given its URI
      # User profile instances are stored in a caching indexed by URI. Cache misses trigger a call to the Aspire
      # user profile JSON API.
      # @param uri [String] the URI of the user profile object
      # @return [LegantoSync::ReadingLists::Aspire::User] the user profile object
      def get_user(uri = nil, data = nil)

        # Return the user from the caching if available
        user = self.users[uri]
        return user if user

        # Get user from the JSON API and add to the caching
        #json = self.api.call("users/#{id_from_uri(uri)}")
        #if json
        #  user = User.new(uri, self, self.email_selector, self.ldap_lookup, json: json)
        #  self.users[user.uri] = user
        #  user
        #else
        #  # TODO: this is a hack, just return the URI for now if the lookup fails
        #  uri
        #end
        nil
      end
    end
  end
end