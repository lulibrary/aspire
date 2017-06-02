module Aspire

  # Implements a hash of User instances indexed by URI
  # The hash can be populated from a CSV file following the Aspire "All User Profiles" report format
  class UserLookup < Hash

    # @!attribute [rw] email_selector
    #   @return [LegantoSync::ReadingLists::Aspire::EmailSelector] the email selector for resolving primary email
    #     addresses
    attr_accessor :email_selector

    # @!attribute [rw] ldap_lookup
    #   @return [LegantoSync::ReadingLists::Aspire::LDAPLookup] the LDAP lookup service for resolving usernames
    attr_accessor :ldap_lookup

    # Initialises a new UserLookup instance
    # @see (Hash#initialize)
    # @param filename [String] the filename of the CSV file used to populate the hash
    # @return [void]
    def initialize(*args, email_selector: nil, filename: nil, ldap_lookup: nil, **kwargs, &block)
      super(*args, **kwargs, &block)
      self.email_selector = email_selector
      self.ldap_lookup = ldap_lookup
      self.load(filename) if filename
    end

    # Populates the hash from a CSV file following the Aspire "All User Profiles" report format
    # @param filename [String] the filename of the CSV file
    # @return [void]
    def load(filename = nil)

      delim = /\s*;\s*/
      CSV.foreach(filename) do |row|

        # Recreate the Aspire user profile JSON API response from the CSV record
        uri = row[3]
        data = {
            'email' => (row[4] || '').split(delim),
            'firstName' => row[0],
            'role' => (row[7] || '').split(delim),
            'surname' => row[1],
            'uri' => row[3]
        }

        # Create the user and set the primary email and username
        user = User.new(uri, nil, self.email_selector, self.ldap_lookup, json: data)

        # Add the user to the lookup table
        self[uri] = user

      end

      nil

    end

    # The abstract base class for user resolvers
    # A UserResolver instance should identify an institutional user from an Aspire user profile and return the user's
    # preferred email address and institutional username

  end

end
