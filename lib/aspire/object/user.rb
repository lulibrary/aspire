require 'aspire/object/base'

module Aspire
  module Object
    # Represents a user profile in the Aspire API
    class User < Base
      # @!attribute [rw] email
      #   @return [Array<String>] the list of email addresses for the user
      attr_accessor :email

      # @!attribute [rw] first_name
      #   @return [String] the user's first name
      attr_accessor :first_name

      # @!attribute [rw] role
      #   @return [Array<String>] the Aspire roles associated with the user
      attr_accessor :role

      # @!attribute [rw] surname
      #   @return [String] the user's last name
      attr_accessor :surname

      # Initialises a new User instance
      # @param uri [String] the URI of the user profile
      # @param factory [Aspire::Object::Factory] the data object factory
      # @param json [Hash] the user profile data from the Aspire JSON API
      # @param ld [Hash] the user profile data from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, json: nil, ld: nil)
        super(uri, factory)
        json ||= {}
        self.email = json['email']
        self.first_name = json['firstName']
        self.role = json['role']
        self.surname = json['surname']
      end

      # Returns a string representation of the user profile (name and emails)
      # @return [String] the string representation of the user profile
      def to_s
        emails = email.nil? || email.empty? ? '' : " <#{email.join('; ')}>"
        "#{first_name} #{surname}#{emails}"
      end
    end
  end
end