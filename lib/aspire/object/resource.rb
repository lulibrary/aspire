require_relative 'base'

module Aspire
  module Object
    # Delegates citation_<property> method calls to the parent resource
    module ResourcePropertyMixin
      CITATION_PROPERTIES = %w[
        authors book_jacket_url date doi edition edition_data eissn has_part
        is_part_of isbn10 isbn13 isbns issn issue issued latest_edition
        local_control_number online_resource page page_end page_start
        place_of_publication publisher title type url volume
      ].freeze

      # Handles citation_<property>() accessor calls by proxying to the parent
      # resource if no instance value is set.
      # The <property> accessor for this instance is called first, and if this
      # returns nil and there is a parent resource (is_part_of), the property
      # accessor of the parent is called.
      # This continues up through the ancestor resources until a value is found.
      # @param method_name [Symbol] the method name
      # Positional and keyword arguments are passed to the property accessor
      def method_missing(method_name, *args, &block)
        property_name = get_property_name_from_method(method_name)
        super if property_name.nil?
        # Try the resource's property first
        value = public_send(property_name, *args, &block)
        return value unless value.nil?
        # Delegate to the parent resource's property if it exists
        #   Call the parent's citation_<property> rather than <property> to
        #   delegate up the ancestor chain.
        if is_part_of
          value = is_part_of.public_send(method_name, *args, &block)
          return value unless value.nil?
        end
        # Otherwise return nil
        nil
      end

      # Returns the property name from a citation_<property> missing method call
      # @param method_name [Symbol] the method name
      # @param _include_all [Boolean] if true, include private/protected methods
      # @return [String, nil] the property name, or nil if not a valid property
      def get_property_name_from_method(method_name, _include_all = false)
        # Ignore method names not beginning with citation_
        return nil unless method_name.to_s.start_with?('citation_')
        # Remove the 'citation_' prefix to get the property name
        property = method_name[9..-1]
        return nil if property.nil? || property.empty?
        # Accept only whitelisted properties
        return nil unless CITATION_PROPERTIES.include?(property)
        # Accept only properties with accessor methods
        return nil unless respond_to?(property)
        # Return the property name
        property
      end

      # Returns true if this method is supported, false if not
      # @param method_name [Symbol] the method name
      # @param include_all [Boolean] if true, include private/protected methods
      # @return [Boolean] true if the method is supported, false otherwise
      def respond_to_missing?(method_name, include_all = false)
        property_name = get_property_name_from_method(method_name, include_all)
        # property_name is not nil if the method is supported
        !property_name.nil?
      end
    end

    # Shortcut methods
    module ResourceShortcutsMixin
      # Returns the title of the journal article associated with this resource
      # @return [String, nil] the journal article title or nil if not applicable
      def article_title
        part_title_by_type('Article')
      end

      # Returns the title of the book associated with this resource
      # @return [String, nil] the book title or nil if not applicable
      def book_title
        part_of_title_by_type('Book')
      end

      # Returns the title of the book chapter associated with this resource
      # @return [String, nil] the book chapter title or nil if not applicable
      def chapter_title
        part_title_by_type('Chapter')
      end

      # Returns the resource title as expected by the Alma reading list loader
      # (Article = article title, book = book title, other = resource title)
      # @return [String] the citation title
      def citation_title
        article_title || book_title || title
      end

      # Returns the title of the journal associated with this resource
      # @return [String, nil] the journal title or nil if not applicable
      def journal_title
        part_of_title_by_type('Journal')
      end

      # Returns the title of the parent resource (book, journal etc.)
      # @return [String] the title of the parent resource
      def part_of_title
        is_part_of ? is_part_of.title : nil
      end

      # Returns the title of the parent resource (book, journal etc.)
      # @return [String] the title of the parent resource
      def part_of_title_by_type(res_type)
        return title if type == res_type
        return is_part_of.title if is_part_of && is_part_of.type == res_type
        nil
      end

      # Returns the title of the part (book chapter, journal article etc.)
      # @return [String] the title of the part
      def part_title
        has_part ? has_part.title : nil
      end

      # Returns the title of the part
      # @param res_type [String] the type of the resource
      # @return [String] the title of the part
      def part_title_by_type(res_type)
        return title if type == res_type
        return has_part.title if has_part && has_part.type == res_type
        nil
      end
    end

    # Represents a resource in the Aspire API
    class Resource < Base
      include ResourcePropertyMixin
      include ResourceShortcutsMixin

      PAGE_RANGE = /(?<start>[\da-zA-Z]*)\s*-\s*(?<end>[\da-zA-Z]*)/

      # @!attribute [rw] authors
      #   @return [Array<String>] the list of authors of the resource
      attr_accessor :authors

      # @!attribute [rw] book_jacket_url
      #   @return [String] the book jacket image URL
      attr_accessor :book_jacket_url

      # @!attribute [rw] date
      #   @return [String] the date of publication
      attr_accessor :date

      # @!attribute [rw] doi
      #   @return [String] the DOI for the resource
      attr_accessor :doi

      # @!attribute [rw] edition
      #   @return [String] the edition
      attr_accessor :edition

      # @!attribute [rw] edition_data
      #   @return [Boolean] true if edition data is available
      attr_accessor :edition_data

      # @!attribute [rw] eissn
      #   @return [String] the electronic ISSN for the resource
      attr_accessor :eissn

      # @!attribute [rw] has_part
      #   @return [Array<Aspire::Object::Resource>] child resources
      attr_accessor :has_part

      # @!attribute [rw] is_part_of
      #   @return [Array<Aspire::Object::Resource>] parent resources
      attr_accessor :is_part_of

      # @!attribute [rw] isbn10
      #   @return [String] the 10-digit ISBN for the resource
      attr_accessor :isbn10

      # @!attribute [rw] isbn13
      #   @return [String] the 13-digit ISBN for the resource
      attr_accessor :isbn13

      # @!attribute [rw] isbns
      #   @return [Array<String>] the list of ISBNs for the resource
      attr_accessor :isbns

      # @!attribute [rw] issn
      #   @return [Array<String>] the ISSN for the resource
      attr_accessor :issn

      # @!attribute [rw] issue
      #   @return [String] the issue
      attr_accessor :issue

      # @!attribute [rw] issued
      #   @return [String] the issue date
      attr_accessor :issued

      # @!attribute [rw] latest_edition
      #   @return [Boolean] true if this is the latest edition
      attr_accessor :latest_edition

      # @!attribute [rw] local_control_number
      #   @return [String] the local control number in the library catalogue
      attr_accessor :local_control_number

      # @!attribute [rw] online_resource
      #   @return [Boolean] true if this is an online resource
      attr_accessor :online_resource

      # @!attribute [rw] page
      #   @return [String] the page range
      attr_accessor :page

      # @!attribute [rw] page_end
      #   @return [String] the end page
      attr_accessor :page_end

      # @!attribute [rw] page_start
      #   @return [String] the start page
      attr_accessor :page_start

      # @!attribute [rw] place_of_publication
      #   @return [String] the place of publication
      attr_accessor :place_of_publication

      # @!attribute [rw] publisher
      #   @return [String] the publisher
      attr_accessor :publisher

      # @!attribute [rw] title
      #   @return [String] the title of the resource
      attr_accessor :title

      # @!attribute [rw] type
      #   @return [String] the type of the resource
      attr_accessor :type

      # @!attribute [rw] url
      #   @return [String] the URL of the resource
      attr_accessor :url

      # @!attribute [rw] volume
      #   @return [String] the volume
      attr_accessor :volume

      # Initialises a new Resource instance
      # @param json [Hash] the resource data from the Aspire JSON API
      # @param ld [Hash] the resource data from the Aspire linked data API
      # @return [void]
      def initialize(uri = nil, factory = nil, json: nil, ld: nil)
        uri ||= json ? json['uri'] : nil
        super(uri, factory)
        return unless json
        init_general(json)
        init_components(json)
        init_edition(json)
        init_identifiers(json)
        init_part(json)
        init_publication(json)
      end

      # Sets the page range and updates the page_start and page_end properties
      # @param value [String] the page range "start-end"
      # @return [String] the page range "start-end"
      def page=(value)
        @page = value.to_s
        match = PAGE_RANGE.match(@page)
        if match.nil?
          # Value is not a range, treat as a single page
          @page_end = @page
          @page_start = @page
        else
          # Value is a range
          @page_end = match[:end]
          @page_start = match[:start]
        end
        @page
      end

      # Returns the page range spanned by the page_start and page_end properties
      # @return [String] the page range "start-end" or page number
      def page_range
        return @page_start if @page_end.nil? || @page_start == @page_end
        return @page_end if @page_start.nil?
        "#{@page_start}-#{@page_end}"
      end

      # Returns a string representation of the resource (the title)
      # @return [String] the string representation of the resource
      def to_s
        title
      end

      protected

      # Sets the component-related properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_components(json)
        has_part = json['hasPart']
        is_part_of = json['isPartOf']
        self.has_part = has_part ? factory.get(uri, json: has_part) : nil
        self.is_part_of = is_part_of ? factory.get(uri, json: is_part_of) : nil
      end

      # Sets the edition-related properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_edition(json)
        self.edition = get_property('edition', json)
        self.edition_data = get_property('editionData', json)
        self.latest_edition = get_property('latestEdition', json)
      end

      # Sets general resource properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_general(json)
        self.authors = get_property('authors', json, single: false)
        self.book_jacket_url = get_property('bookjacketURL', json)
        self.issued = json ? json['issued'] : nil # TODO
        self.online_resource = get_boolean('onlineResource', json)
        self.title = get_property('title', json)
        self.type = get_property('type', json)
        self.url = get_property('url', json, is_url: true)
      end

      # Sets the identifier properties (DOI, ISBN/ISSN, local control number)
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_identifiers(json)
        self.doi = get_property('doi', json)
        self.eissn = get_property('eissn', json)
        self.isbn10 = get_property('isbn10', json)
        self.isbn13 = get_property('isbn13', json)
        self.isbns = get_property('isbns', json, single: false)
        self.issn = get_property('issn', json)
        self.local_control_number = get_property('lcn', json)
      end

      # Sets the pagination-related properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_pagination(json)
        self.page_end = get_property('pageEnd', json)
        self.page_start = get_property('pageStart', json)
        # Override page_end and page_start if the page range is specified
        range = get_property('page', json)
        self.page = range unless range.nil? || range.empty?
      end

      # Sets the part-related properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_part(json)
        init_pagination(json)
        self.issue = get_property('issue', json)
        self.volume = get_property('volume', json)
      end

      # Sets the publication-related properties
      # @param json [Hash] the resource data from the Aspire JSON API
      # @return [void]
      def init_publication(json)
        self.date = get_property('date', json)
        self.place_of_publication = get_property('placeOfPublication', json)
        self.publisher = get_property('publisher', json)
      end
    end
  end
end