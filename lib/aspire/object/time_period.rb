require 'aspire/object/base'

module Aspire
  module Object
    # Represents the time period covered by a reading list in the Aspire API
    class TimePeriod < Base
      # @!attribute [rw] active
      #   @return [Boolean] true if the time period is currently active
      attr_accessor :active

      # @!attribute [rw] end_date
      #   @return [Date] the end of the time period
      attr_accessor :end_date

      # @!attribute [rw] start_date
      #   @return [Date] the start of the time period
      attr_accessor :start_date

      # @!attribute [rw] title
      #   @return [String] the title of the time period
      attr_accessor :title

      # Initialises a new TimePeriod instance
      def initialize(uri, factory, json: nil, ld: nil)
        super(uri, factory)
        json ||= {}
        self.active = get_property('active', json)
        self.end_date = get_date('endDate', json)
        self.start_date = get_date('startDate', json)
        self.title = get_property('title', json)
      end

      # Returns a string representation of the TimePeriod instance (the title)
      # @return [String] the string representation of the TimePeriod instance
      def to_s
        title.to_s
      end

      # Returns the academic year containing this time period
      # @return [Integer, nil] the academic year, or nil if unspecified
      def year
        result = title.split('-')[0]
        result ? result.to_i : nil
      end
    end
  end
end