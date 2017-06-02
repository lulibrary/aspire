module Aspire
  # Defines filter criteria for the ListIterator
  class ListFilter
    # Initialises a new ListFilter
    def initialize()
      @filters = {}
    end

    # Adds a new filter value
    # @param type [Symbol] the filter type
    # @param value [Object] the filter value or range
    # @return [void]
    def add(type, value)
      if @filters.include?(type)
        @filters[type].append(value)
      else
        @filters[type] = [value]
      end
    end

    # Sets a new filter value, overwriting existing definitions
    # @param type [Symbol] the filter type
    # @param value [Object] the filter value, list or range
    # @return [void]
    def set(type, value)
      @filters[type] = [value]
    end
  end

  # Iterates over lists from the Aspire AllLists report
  class ListIterator
    # @!attribute [rw] file
    #   @return [String] the default AllLists report filename
    attr_accessor :file

    # Initialises a new ListIterator
    # @param file [String] the default AllLists report filename
    def initialize(file: nil)
      self.file = file
    end
  end
end