require 'aspire/object/base'

module Aspire
  module Object
    # Represents a digitisation record in the Aspire API
    class Digitisation < Base
      # @!attribute [rw] bundle_id
      #   @return [String] the digitisation bundle ID
      attr_accessor :bundle_id

      # @!attribute [rw] request_id
      #   @return [String] the digitisation request ID
      attr_accessor :request_id

      # @!attribute [rw] request_status
      #   @return [String] the digitisation request status
      attr_accessor :request_status

      # Initialises a new Digitisation instance
      # @param json [Hash] the parsed JSON data from the JSON API
      # @param ld [Hash] the parsed JSON data from the linked data API
      # @return [void]
      def initialize(json: nil, ld: nil)
        if json
          self.bundle_id = json['bundleId']
          self.request_id = json['requestId']
          self.request_status = json['requestStatus']
        else
          self.bundle_id = nil
          self.request_id = nil
          self.request_status = nil
        end
      end

      # Returns a string representation of the Digitisation instance (the
      # request ID)
      # @return [String] the string representation of the Digitisation instance
      def to_s
        request_id.to_s
      end
    end
  end
end