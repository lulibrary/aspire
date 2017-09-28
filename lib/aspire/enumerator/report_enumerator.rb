require 'csv'

require 'aspire/enumerator/base'

module Aspire
  # Enumerator classes for Aspire reading list processing
  module Enumerator
    # Enumerates rows from an exported Aspire report CSV (All Lists, All User
    # Profiles etc.) with optional filtering
    class ReportEnumerator < Base
      # @!attribute [rw] file
      #   @return [String] the filename of the report
      attr_accessor :file

      # @!attribute [rw] filters
      #   @return [Array<Proc>] a list of filters to select rows for processing
      attr_accessor :filters

      # Initialises a new ListReport instance
      # @param file [String] the filename of the report
      # @param filters [Array<Proc>] a list of filters to select rows for
      #   processing. Each proc accepts a parsed row from the CSV file and
      #   returns true to accept it or false to reject it. All filters must
      #   return true for the row to be yielded.
      # @return [void]
      def initialize(file = nil, filters = nil)
        self.file = file
        self.filters = filters
      end

      # Enumerates the report rows
      # @return [void]
      def enumerate(*_args, **_kwargs)
        CSV.foreach(file, converters: date_converter, headers: true, encoding: 'ISO-8859-1') do |row|
          yielder << row if filter(row)
        end
      end

      private

      # Returns a YYYY-MM-DD date converter for the CSV processor
      # @return [Proc] the date converter
      def date_converter
        lambda do |s|
          begin
            Date.strptime(s, '%Y-%m-%d')
          rescue ArgumentError
            s
          end
        end
      end

      # Returns true if the row passes all filters, false otherwise
      def filter(row)
        # Return true if no filters are defined
        return true if filters.nil? || filters.empty?
        # Return false if any of the filters returns false
        filters.each { |f| return false unless f.call(row) }
        # All filters passed, return true
        true
      end
    end
  end
end