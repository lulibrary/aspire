require 'csv'

require 'aspire/enumerator/report_enumerator'
require 'aspire/object/user'

module Aspire
  # Implements a hash of User instances indexed by URI
  # The hash can be populated from an Aspire All User Profiles report CSV file
  class UserLookup
    # @!attribute [rw] store
    #   @return [Object] a hash-like object mapping user URIs to their JSON data
    attr_accessor :store

    # Initialises a new UserLookup instance
    # @see (Hash#initialize)
    # @param filename [String] the filename of the CSV file to populate the hash
    # @return [void]
    def initialize(filename: nil, store: nil)
      self.store = store || {}
      load(filename) if filename
    end

    # Returns an Aspire::Object::User instance for a URI
    # @param uri [String] the URI of the user
    # @param factory [Aspire::Object::Factory] the data object factory
    # @return [Aspire::Object::User] the user
    def [](uri, factory = nil)
      data = store[uri]
      data.nil? ? nil : Aspire::Object::User.new(uri, factory, json: data)
    end

    # Populates the store from an All User Profiles report CSV file
    # @param filename [String] the filename of the CSV file
    # @return [void]
    def load(filename = nil)
      delim = /\s*;\s*/ # The delimiter for email and role lists
      enum = Aspire::Enumerator::ReportEnumerator.new(filename).enumerator
      enum.each do |row|
        # Construct a JSON data structure for the user
        uri = row[3]
        data = csv_to_json_api(row, email_delim: delim, role_delim: delim)
        csv_to_json_other(row, data)
        # Store the JSON data in the lookup table
        store[uri] = data
      end
    end

    # Proxies missing methods to the store
    # @param method [Symbol] the method name
    # @param args [Array] the method arguments
    # @param block [Proc] the code block
    # @return [Object] the store method result
    def method_missing(method, *args, &block)
      super unless store.respond_to?(method)
      store.public_send(method, *args, &block)
    end

    # Proxies missing method respond_to? to the store
    # @param method [Symbol] the method name
    # @param include_private [Boolean] if true, include private methods,
    #   otherwise include only public methods
    # @return [Boolean] true if the store supports the method, false otherwise
    def respond_to_missing?(method, include_private = false)
      store.respond_to?(method, include_private)
    end

    private

    def csv_to_json(row)
      # Recreate the Aspire user profile JSON API response from the CSV record
      data = csv_to_json_api(row)
      # Add other report fields which aren't part of the JSON API response
      csv_to_json_other(row, data)
    end

    # Adds CSV fields which mirror the Aspire user profile JSON API fields
    # @param row [Array] the fields from the All User Profiles report CSV
    # @param data [Hash] the JSON representation of the user profile
    # @return [Hash] the JSON data hash
    def csv_to_json_api(row, data = {}, email_delim: nil, role_delim: nil)
      data['email'] = (row[4] || '').split(email_delim)
      data['firstName'] = row[0]
      data['role'] = (row[7] || '').split(role_delim)
      data['surname'] = row[1]
      data['uri'] = row[3]
      data
    end

    # Adds CSV fields which aren't part of the Aspire user profile JSON API
    # @param row [Array] the fields from the All User Profiles report CSV
    # @param data [Hash] the JSON representation of the user profile
    # @return [Hash] the JSON data hash
    def csv_to_json_other(row, data = {})
      # The following fields are not present in the JSON API response but are in
      # the All User Profiles report - they are included for completeness.
      data['jobRole'] = row[5] || ''
      data['lastLogin'] = row[8]
      data['name'] = row[2] || ''
      data['visibility'] = row[6] || ''
      data
    end
  end
end