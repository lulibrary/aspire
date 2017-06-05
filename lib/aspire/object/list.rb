require 'aspire/object/base'

module Aspire
  module Object
    # The abstract base class of reading list objects (items, lists, sections)
    class ListBase < Aspire::Object::Base
      # The Aspire linked data API returns properties of the form
      # "#{KEY_PREFIX}_n" where n is a 1-based numeric index denoting the
      # display order of the property.
      KEY_PREFIX = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'.freeze

      # @!attribute [rw] entries
      #   @return [Array<Aspire::Object::ListBase>] the ordered list of child
      #     objects
      attr_accessor :entries

      # @!attribute [rw] parent
      #   @return [Aspire::Object::ListBase] the parent reading list object of
      #     this object
      attr_accessor :parent

      # Initialises a new ListBase instance
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [Aspire::Object::Factory]
      #   a factory returning ListBase subclass instances
      # @param parent [Aspire::Object::ListBase]
      #   the parent reading list object of this object
      # @param json [Hash] the parsed JSON data from the Aspire JSON API
      # @param ld [Hash] the parsed JSON data from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, parent = nil, json: nil, ld: nil)
        super(uri, factory)
        self.parent = parent
        self.entries = get_entries(json: json, ld: ld)
      end

      # Iterates over the child reading list objects in display order
      # @yield [entry] passes the child reading list object to the block
      # @yieldparam entry [Aspire::Object::ListBase] the reading list object
      def each(&block)
        entries.each(&block)
      end

      # Iterates over the child list items in display order (depth-first tree
      # traversal)
      # @yield [entry] passes the list item to the block
      # @yieldparam entry [Aspire::Object::ListItem] the reading list item
      # @return [void]
      def each_item(&block)
        each do |entry|
          if entry.is_a?(ListItem)
            # Pass the list item to the block
            yield(entry) if block_given?
          else
            # Iterate the entry's list items
            entry.each_item(&block)
          end
        end
        nil
      end

      # Iterates over the child list sections in display order (depth-first tree
      # traversal)
      # @yield [entry] passes the list section to the block
      # @yieldparam entry [Aspire::Object::ListSection] the reading list section
      # @return [void]
      def each_section(&block)
        each do |entry|
          if entry.is_a?(List)
            # Iterate the list's sections
            entry.each_section(&block)
          elsif entry.is_a?(ListSection)
            # Pass the list section to the block
            yield(entry) if block_given?
          end
        end
        nil
      end

      # Returns a list of child reading list objects in display order
      # @param json [Hash] the parsed JSON data from the Aspire JSON API
      # @param ld [Hash] the parsed JSON data from the Aspire linked data API
      # @return [Array<Aspire::Object::ListBase>]
      #   the ordered list of child objects
      def get_entries(json: nil, ld: nil)
        entries = []
        data = ld ? ld[self.uri] : nil
        if data
          data.each do |key, value|
            prefix, index = key.split('_')
            next unless prefix == KEY_PREFIX
            uri = value[0]['value']
            entries[index.to_i - 1] = factory.get(uri, self, ld: ld)
          end
        end
        entries
      end

      # Returns the child items of this object in display order
      # @return [Array<Aspire::Object::ListItem>] the child reading list items
      def items
        result = []
        each_item { |item| result.push(item) }
        result
      end

      # Returns the number of items in the list
      # @param item_type [Symbol] selects the list entry type to count
      #   :entry = top-level item or section
      #   :item  = list item (default)
      #   :section = top-level section
      # @return [Integer] the number of list entry instances
      def length(item_type = nil)
        item_type ||= :item
        case item_type
        when :entry
          # Return the number of top-level entries (items and sections)
          self.entries.length
        when :item
          # Return the number of list items as the sum of list items in each entry
          self.entries.reduce(0) { |count, entry| count + entry.length(:item) }
        when :section
          # Return the number of top-level sections
          self.sections.length
        end
      end

      # Returns the parent list of this object
      # @return [LegantoSync::ReadingLists::Aspire::List] the parent reading list
      def parent_list
        self.parent_lists[0]
      end

      # Returns the ancestor lists of this object (nearest ancestor first)
      # @return [Array<LegantoSync::ReadingLists::Aspire::List>] the ancestor reading lists
      def parent_lists
        self.parents(List)
      end

      # Returns the parent section of this object
      # @return [LegantoSync::ReadingLists::Aspire::ListSection] the parent reading list section
      def parent_section
        self.parent_sections[0]
      end

      # Returns the ancestor sections of this object (nearest ancestor first)
      # @return [Array<LegantoSync::ReadingLists::Aspire::ListSection>] the ancestor reading list sections
      def parent_sections
        self.parents(ListSection)
      end

      # Returns a list of ancestor reading list objects of this object (nearest ancestor first)
      # Positional parameters are the reading list classes to include in the result. If no classes are specified,
      # all classes are included.
      # @yield [ancestor] passes the ancestor to the block
      # @yieldparam ancestor [LegantoSync::ReadingLists::Aspire::ListObject] the reading list object
      # @yieldreturn [Boolean] if true, include in the ancestor list, otherwise ignore
      def parents(*classes)
        result = []
        ancestor = self.parent
        until ancestor.nil?
          # Filter ancestors by class
          if classes.nil? || classes.empty? || classes.include?(ancestor.class)
            # If a block is given, it must return true for the ancestor to be included
            result.push(ancestor) unless block_given? && !yield(ancestor)
          end
          ancestor = ancestor.parent
        end
        result
      end

      # Returns the child sections of this object
      # @return [Array<LegantoSync::ReadingLists::Aspire::ListSection>] the child reading list sections
      def sections
        entries.select { |e| e.is_a?(ListSection) }
      end
    end

    # Represents a reading list in the Aspire API
    class List < ListBase
      # @!attribute [rw] created
      #   @return [DateTime] the creation timestamp of the list
      attr_accessor :created

      # @!attribute [rw] creator
      #   @return [Array<LegantoSync::ReadingLists::Aspire::User>] the list of
      #     creators of the reading list
      attr_accessor :creator

      # @!attribute [rw] description
      #   @return [String] the description of the list
      attr_accessor :description

      # @!attribute [rw] items
      #   @return [Hash<String, LegantoSync::ReadingLists::Aspire::ListItem>]
      #     a hash of ListItems indexed by item URI
      attr_accessor :items

      # @!attribute [rw] last_published
      #   @return [DateTime] the timestamp of the most recent list publication
      attr_accessor :last_published

      # @!attribute [rw] last_updated
      #   @return [DateTime] the timestamp of the most recent list update
      attr_accessor :last_updated

      # @!attribute [rw] list_history
      #   @return [Hash] the parsed data from the Aspire list history JSON API
      attr_accessor :list_history

      # @!attribute [rw] modules
      #   @return [Array<LegantoSync::ReadingLists::Aspire::Module>] the list of
      #     modules referencing this list
      attr_accessor :modules

      # @!attribute [rw] name
      #   @return [String] the reading list name
      attr_accessor :name

      # @!attribute [rw] owner
      #   @return [LegantoSync::ReadingLists::Aspire::User] the list owner
      attr_accessor :owner

      # @!attribute [rw] publisher
      #   @return [LegantoSync::ReadingLists::Aspire::User] the list publisher
      attr_accessor :publisher

      # @!attribute [rw] time_period
      #   @return [LegantoSync::ReadingLists::Aspire::TimePeriod] the time
      #     period covered by the list
      attr_accessor :time_period

      # @!attribute [rw] uri
      #   @return [String] the URI of the reading list
      attr_accessor :uri

      # Initialises a new List instance
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [LegantoSync::ReadingLists::Aspire::Factory] a factory
      #   returning ReadingListBase subclass instances
      # @param parent [LegantoSync::ReadingLists::Aspire::ListObject] the parent
      #   reading list object of this object
      # @param json [Hash] the data containing the properties of the
      #   ReadingListBase instance from the Aspire JSON API
      # @param ld [Hash] the data containing the properties of the
      #   ReadingListBase instance from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, parent = nil, json: nil, ld: nil)
        # Set properties from the Reading Lists API
        # - this must be called before the superclass constructor so that item
        #   details are available
        json = self.set_data(uri, factory, json)
        # Initialise the superclass
        super(uri, factory)
        # Set properties from the linked data API data
        set_linked_data(uri, factory, ld)
      end

      # Returns the number of items in the list
      # @see (LegantoSync::ReadingLists::Aspire::ListObject#length)
      def length(item_type = nil)
        item_type ||= :item
        # The item length of a list is the length of the items property,
        # avoiding the need to sum list entry lengths
        item_type == :item ? self.items.length : super(item_type)
      end

      # Retrieves the list details and history from the Aspire JSON API
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [LegantoSync::ReadingLists::Aspire::Factory] a factory
      #   returning ReadingListBase subclass instances
      # @param json [Hash] the data containing the properties of the reading
      #   list object from the Aspire JSON API
      # @return [void]
      def set_data(uri, factory, json = nil)
        api = factory.api
        list_id = self.id_from_uri(uri)

        # Default values
        self.modules = nil
        self.name = nil
        self.time_period = nil

        # Get the list details
        puts("  - list details API: #{list_id}")
        options = { bookjacket: 1, draft: 1, editions: 1, history: 0 }
        if json.nil?
          json = api.call("lists/#{list_id}", **options) # do |response, data|
          #   File.open("#{dir}/details.json", 'w') { |f| f.write(JSON.pretty_generate(data)) }
          # end
        end

        # Get the list history
        puts("  - list history API: #{list_id}")
        self.list_history = api.call("lists/#{list_id}/history") # do |response, data|
        #   File.open("#{dir}/history.json", 'w') { |f| f.write(JSON.pretty_generate(data)) }
        # end

        # A hash mapping item URI to item
        self.items = {}

        if json
          json['items'].each { |item| self.items[item['uri']] = item } if json['items']
          self.modules = json['modules'].map { |m| Module.new(m['uri'], factory, json: m) } if json['modules']
          self.name = json['name']
          period = json['timePeriod']
          self.time_period = period ? TimePeriod.new(period['uri'], factory, json: period) : nil
        end

        # Return the parsed JSON data from the Aspire list details JSON API
        json
      end

      # Sets reading list properties from the Aspire linked data API
      # @return [void]
      def set_linked_data(uri, factory, ld = nil)
        list_data = ld[self.uri]
        has_creator = self.get_property('http://rdfs.org/sioc/spec/has_creator', list_data, single: false) || []
        has_owner = self.get_property('http://purl.org/vocab/resourcelist/schema#hasOwner', list_data, single: false) || []
        published_by = self.get_property('http://purl.org/vocab/resourcelist/schema#publishedBy', list_data)
        self.created = self.get_date('http://purl.org/vocab/resourcelist/schema#created', list_data)
        self.creator = has_creator.map { |uri| factory.get(uri, ld: ld) }
        self.description = self.get_property('http://purl.org/vocab/resourcelist/schema#description', list_data)
        self.last_published = self.get_date('http://purl.org/vocab/resourcelist/schema#lastPublished', list_data)
        self.last_updated = self.get_date('http://purl.org/vocab/resourcelist/schema#lastUpdated', list_data)
        if self.modules.nil?
          mods = self.get_property('http://purl.org/vocab/resourcelist/schema#usedBy', list_data, single: false)
          self.modules = mods.map { |uri| factory.get(uri, ld: ld) } if mods
        end
        unless self.name
          self.name = self.get_property('http://rdfs.org/sioc/spec/name', list_data)
        end
        self.owner = has_owner.map { |uri| self.factory.get(uri, ld: ld) }
        self.publisher = self.factory.get(published_by, ld: ld)
        nil
      end

      # Returns a string representation of the List instance (the reading list name)
      # @return [String] the string representation of the List instance
      def to_s
        self.name || super
      end
    end

    # Represents a reading list item (citation) in the Aspire API
    class ListItem < ListBase
      # @!attribute [rw] digitisation
      #   @return [LegantoSync::ReadingLists::Aspire::Digitisation]
      #     the digitisation details for the item
      attr_accessor :digitisation

      # @!attribute [rw] importance
      #   @return [String] the importance of the item
      attr_accessor :importance

      # @!attribute [rw] library_note
      #   @return [String] the internal library note for the item
      attr_accessor :library_note

      # @!attribute [rw] local_control_number
      #   @return [String] the identifier of the resource in the local library
      #     management system
      attr_accessor :local_control_number

      # @!attribute [rw] note
      #   @return [String] the public note for the item
      attr_accessor :note

      # @!attribute [rw] resource
      #   @return [LegantoSync::ReadingLists::Aspire::Resource] the resource for
      #     the item
      attr_accessor :resource

      # @!attribute [rw] student_note
      #   @return [String] the public note for the item
      attr_accessor :student_note

      # @!attribute [rw] title
      #   @return [String] the title of the item
      attr_accessor :title

      # Initialises a new ListItem instance
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [LegantoSync::ReadingLists::Aspire::Factory]
      #   a factory returning ReadingListBase subclass instances
      # @param parent [LegantoSync::ReadingLists::Aspire::ListObject]
      #   the parent reading list object of this object
      # @param json [Hash] the parsed JSON data hash containing the properties
      #   of the ReadingListBase instance from the Aspire JSON API
      # @param ld [Hash] the parsed JSON data hash containing the properties of
      #   the ReadingListBase instance from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, parent = nil, json: nil, ld: nil)
        super(uri, factory, parent, json: json, ld: ld)

        if json.nil?
          # Get the JSON API item data from the parent list
          owner = self.parent_list
          json = owner && owner.items ? owner.items[uri] : nil
        end

        # item_ld = ld ? ld[uri] : nil

        # The digitisation request
        digitisation_json = json ? json['digitisation'] : nil

        digitisation_ld = nil  # TODO: linked data digitisation - we don't use Talis' digitisation service
        if digitisation_json || digitisation_ld
          digitisation = Digitisation.new(json: digitisation_json, ld: digitisation_ld)
        else
          digitisation = nil
        end

        # The resource
        resource_json = json ? json['resource'] : nil
        if resource_json.is_a?(Array)
          resource_json = resource_json.empty? ? nil : resource_json[0]
          puts("WARNING: selected first resource of #{resource_json}") if resource_json  # TODO: remove once debugged!
        end
        resource = resource_json ? factory.get(resource_json['uri'], json: resource_json) : nil
        #resource_json = json ? json['resource'] : nil
        #resource_uri = get_property('http://purl.org/vocab/resourcelist/schema#resource', item_ld)
        #resource = resource_json # || resource_uri ? factory.get(resource_uri, json: resource_json, ld: ld) : nil

        self.digitisation = digitisation
        self.importance = self.get_property('importance', json)
        self.library_note = self.get_property('libraryNote', json)
        self.local_control_number = self.get_property('lcn', json)
        self.note = self.get_property('note', json)
        self.resource = resource
        self.student_note = self.get_property('studentNote', json)
        self.title = self.get_property('title', json)

      end

      # Returns the length of the list item
      # @see (LegantoSync::ReadingLists::Aspire::ListObject#length)
      def length(item_type = nil)
        item_type ||= :item
        # List items return an item length of 1 to enable summation of
        #   list/section lengths
        item_type == :item ? 1 : super(item_type)
      end

      # Returns the resource title or public note if no resource is available
      # @param alt [Symbol] the alternative if no resource is available
      #   :library_note or :private_note = the library note
      #   :note = the student note, or the library note if no student note is
      #     available
      #   :public_note, :student_note = the student note
      #   :uri = the list item URI
      # @return [String] the resource title or alternative
      def title(alt = nil)
        # Return the resource title if available, otherwise return the specified
        #   alternative
        return self.resource.title || @title if self.resource
        case alt
        when :library_note, :private_note
          self.library_note || nil
        when :note
          self.student_note || self.note || self.library_note || nil
        when :public_note, :student_note
          self.student_note || self.note || nil
        when :uri
          self.uri
        else
          nil
        end
      end

      # Returns a string representation of the ListItem instance (the citation
      #   title or note)
      # @return [String] the string representation of the ListItem instance
      def to_s
        self.title(:public_note).to_s
      end
    end

    # Represents a reading list section in the Aspire API
    class ListSection < ListBase
      # @!attribute [rw] description
      #   @return [String] the reading list section description
      attr_accessor :description

      # @!attribute [rw] name
      #   @return [String] the reading list section name
      attr_accessor :name

      # Initialises a new ListSection instance
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [LegantoSync::ReadingLists::Aspire::Factory]
      #   a factory returning ReadingListBase subclass instances
      # @param parent [LegantoSync::ReadingLists::Aspire::ListObject]
      #   the parent reading list object of this object
      # @param json [Hash] the parsed JSON data hash containing the properties
      #   of the ReadingListBase instance from the Aspire JSON API
      # @param ld [Hash] the parsed JSON data hash containing the properties of
      #   the ReadingListBase instance from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, parent = nil, json: nil, ld: nil)
        super(uri, factory, parent, json: json, ld: ld)
        section_ld = ld[uri]
        self.description = self.get_property('http://purl.org/vocab/resourcelist/schema#description', section_ld)
        self.name = self.get_property('http://rdfs.org/sioc/spec/name', section_ld)
      end

      # Returns a string representation of the ListSection instance (the section
      #   name)
      # @return [String] the string representation of the ListSection instance
      def to_s
        self.name || super
      end
    end
  end
end