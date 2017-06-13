require 'aspire/object/base'
require 'aspire/properties'

module Aspire
  module Object
    # Represents a module in the Aspire API
    class Module < Base
      include Aspire::Properties

      # @!attribute [rw] code
      #   @return [String] the module code
      attr_accessor :code

      # @!attribute [rw] name
      #   @return [String] the module name
      attr_accessor :name

      # Initialises a new Module instance
      def initialize(uri, factory, json: nil, ld: nil)
        super(uri, factory)
        self.code =
          get_property('code', json) ||
          get_property(AIISO_CODE, ld)
        self.name =
          get_property('name', json) ||
          get_property(AIISO_NAME, ld)
      end

      # Returns a string representation of the Module instance (the module name)
      # @return [String] the string representation of the Module instance
      def to_s
        name.to_s || super
      end
    end
  end
end