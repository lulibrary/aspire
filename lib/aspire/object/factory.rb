require 'aspire/object/list'
require 'aspire/object/module'
require 'aspire/object/resource'
require 'aspire/util'

module Aspire
  module Object
    # A factory returning reading list objects given the object's URI
    class Factory
      include Aspire::Util

      # @!attribute [rw] api
      #   @return [LegantoSync::ReadingLists::Aspire::API] the Aspire API instance used to retrieve data
      attr_accessor :api

      # @!attribute [rw] email_selector
      #   @return [LegantoSync::ReadingLists::Aspire::EmailSelector] the email selector for identifying users'
      #     primary email addresses
      attr_accessor :email_selector

      # @!attribute [rw] ldap_lookup
      #   @return [LegantoSync::ReadingLists::Aspire::LDAPLookup] the LDAP lookup instance for identifying users'
      #     usernames
      attr_accessor :ldap_lookup

      # @!attribute [rw] users
      #   @return [Hash<String, LegantoSync::ReadingLists::Aspire::User>] a hash of user profiles indexed by URI
      attr_accessor :users

      # Initialises a new ReadingListFactory instance
      # @param api [LegantoSync::ReadingLists::Aspire::API] the Aspire API instance used to retrieve data
      # @param users [Hash<String, LegantoSync::ReadingLists::Aspire::User>] a hash mapping user profile URIs to users
      # @return [void]
      def initialize(api, email_selector: nil, ldap_lookup: nil, users: nil)
        self.api = api
        self.email_selector = email_selector
        self.ldap_lookup = ldap_lookup
        self.users = users || {}
      end

      # Returns a new reading list object (ReadingListBase subclass) given its URI
      # @param uri [String] the URI of the object
      # @param parent [LegantoSync::ReadingLists::Aspire::ListObject] the parent reading list object of this object
      # @return [LegantoSync::ReadingLists::Aspire::ListObject] the reading list object
      def get(uri = nil, parent = nil, json: nil, ld: nil)
        return nil if uri.nil? || uri.empty?
        if uri.include?('/items/')
          # Get item data from the parent list (from the JSON API) rather than the Linked Data API
          ListItem.new(uri, self, parent)
        elsif uri.include?('/resources/') && !json.nil?
          # Get resource data from the JSON API rather than the Linked Data API if available
          Resource.new(uri, self, json: json, ld: ld)
        elsif uri.include?('/users/')
          get_user(uri, ld)
        else
          # Get lists, modules, resources and sections from the Linked Data API
          # If the URI is present in the linked data hash, the corresponding data is used. Otherwise, the data is
          # loaded from the linked data API.
          puts(uri)
          ld = self.api.get_json(uri, expand_path: false) if ld.nil? || !ld.has_key?(uri)
          if uri.include?('/lists/')
            List.new(uri, self, parent, json: json, ld: ld)
          elsif uri.include?('/modules/')
            Module.new(uri, self, json: json, ld: ld)
          elsif uri.include?('/resources/')
            Resource.new(uri, self, json: json, ld: ld)
          elsif uri.include?('/sections/')
            ListSection.new(uri, self, parent, json: json, ld: ld)
          else
            nil
          end
        end
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