require 'aspire/object/base'

module Aspire
  # Property name URIs
  module Properties
    CREATED = 'http://purl.org/vocab/resourcelist/schema#created'.freeze
    DESCRIPTION = 'http://purl.org/vocab/resourcelist/schema#description'
                  .freeze
    HAS_CREATOR = 'http://rdfs.org/sioc/spec/has_creator'.freeze
    HAS_OWNER = 'http://purl.org/vocab/resourcelist/schema#hasOwner'.freeze
    LAST_PUBLISHED = 'http://purl.org/vocab/resourcelist/schema#lastPublished'
                     .freeze
    LAST_UPDATED = 'http://purl.org/vocab/resourcelist/schema#lastUpdated'
                   .freeze
    NAME = 'http://rdfs.org/sioc/spec/name'.freeze
    PUBLISHED_BY = 'http://purl.org/vocab/resourcelist/schema#publishedBy'
                   .freeze
    USED_BY = 'http://purl.org/vocab/resourcelist/schema#usedBy'.freeze
  end

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
      # @return [Array<Aspire::Object::ListBase>] the ordered list of child
      #   objects
      def get_entries(json: nil, ld: nil)
        entries = []
        data = ld ? ld[uri] : nil
        return entries unless data
        data.each { |key, value| get_ordered_entry(key, value, entries) }
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
        # Return the number of top-level entries (items and sections)
        return entries.length if item_type == :entry
        # Return the sum of the number of list items in each entry
        if item_type == :item
          entries.reduce(0) { |count, entry| count + entry.length(:item) }
        end
        # Return the number of top-level sections
        return sections.length if item_type == :section
        # Otherwise return 0 for unknown item types
        0
      end

      # Returns the parent list of this object
      # @return [Aspire::Object::List] the parent reading list
      def parent_list
        parent_lists[0]
      end

      # Returns the ancestor lists of this object (nearest ancestor first)
      # @return [Array<Aspire::Object::List>] the ancestor reading lists
      def parent_lists
        parents(List)
      end

      # Returns the parent section of this object
      # @return [Aspire::Object::ListSection] the parent reading list section
      def parent_section
        parent_sections[0]
      end

      # Returns the ancestor sections of this object (nearest ancestor first)
      # @return [Array<Aspire::Object::ListSection>] the ancestor reading list
      #   sections
      def parent_sections
        parents(ListSection)
      end

      # Returns a list of ancestor reading list objects of this object (nearest
      #   ancestor first)
      # Positional parameters are the reading list classes to include in the
      # result. If no classes are specified, all classes are included.
      # @yield [ancestor] passes the ancestor to the block
      # @yieldparam ancestor [Aspire::Object::ListBase] the reading list object
      # @yieldreturn [Boolean] if true, include in the ancestor list, otherwise
      #   ignore
      def parents(*classes, &block)
        result = []
        ancestor = parent
        until ancestor.nil?
          result.push(ancestor) if parents_include?(ancestor, *classes, &block)
          ancestor = ancestor.parent
        end
        result
      end

      # Returns true if the should be included with the parents, false otherwise
      # @param ancestor [Aspire::Object::ListBase] the reading list object
      # Remaining positional parameters are the reading list classes to include
      # in the result. If no classes are specified, all classes are included.
      # @yield [ancestor] passes the ancestor to the block
      # @yieldparam ancestor [Aspire::Object::ListBase]
      #   the reading list object
      # @yieldreturn [Boolean] if true, include in the ancestor list, otherwise
      #   ignore
      def parents_include?(ancestor, *classes)
        # Filter ancestors by class
        if classes.nil? || classes.empty? || classes.include?(ancestor.class)
          # The ancestor is allowed by class, but may be disallowed by a code
          # block which returns false. If the code block returns true or is not
          # given, the ancestor is included.
          return block_given? && !yield(ancestor) ? false : true
        end
        # Otherwise the ancestor is not allowed by class
        false
      end

      # Returns the child sections of this object
      # @return [Array<Aspire::Object::ListSection>] the child list sections
      def sections
        entries.select { |e| e.is_a?(ListSection) }
      end

      private

      # Adds a child object to the entries array if key is an ordered property
      # @param key [String] the property name URI
      # @param value [Hash] the property value hash
      # @param entries [Array<Aspire::Object::ListBase>] the ordered list of
      #   child objects
      # @return [Aspire::Object::ListBase] the list object
      def get_ordered_entry(key, value, entries)
        prefix, index = key.split('_')
        return nil unless prefix == KEY_PREFIX
        uri = value[0]['value']
        entries[index.to_i - 1] = factory.get(uri, self, ld: ld)
      end
    end

    # Represents a reading list in the Aspire API
    class List < ListBase
      include Properties

      # @!attribute [rw] created
      #   @return [DateTime] the creation timestamp of the list
      attr_accessor :created

      # @!attribute [rw] creator
      #   @return [Array<Aspire::Object::User>] the reading list creators
      attr_accessor :creator

      # @!attribute [rw] description
      #   @return [String] the description of the list
      attr_accessor :description

      # @!attribute [rw] items
      #   @return [Hash<String, Aspire::Object::ListItem>] a hash of ListItems
      #     indexed by item URI
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
      #   @return [Array<Aspire::Object::Module>] the modules referencing this
      #     list
      attr_accessor :modules

      # @!attribute [rw] name
      #   @return [String] the reading list name
      attr_accessor :name

      # @!attribute [rw] owner
      #   @return [Aspire::Object::User] the list owner
      attr_accessor :owner

      # @!attribute [rw] publisher
      #   @return [Aspire::Object::User] the list publisher
      attr_accessor :publisher

      # @!attribute [rw] time_period
      #   @return [Aspire::Object::TimePeriod] the period covered by the list
      attr_accessor :time_period

      # @!attribute [rw] uri
      #   @return [String] the URI of the reading list
      attr_accessor :uri

      # Initialises a new List instance
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [Aspire::Object::Factory] a factory
      #   returning ReadingListBase subclass instances
      # @param parent [Aspire::Object::ListBase] the parent
      #   reading list object of this object
      # @param json [Hash] the data containing the properties of the
      #   ListBase instance from the Aspire JSON API
      # @param ld [Hash] the data containing the properties of the
      #   ListBase instance from the Aspire linked data API
      # @return [void]
      def initialize(uri, factory, parent = nil, json: nil, ld: nil)
        # Set properties from the Reading Lists JSON API
        # - this must be called before the superclass constructor so that item
        #   details are available
        init_json_data(uri, factory, json)
        # Initialise the superclass
        super(uri, factory)
        # Set properties from the linked data API data
        init_linked_data(uri, factory, ld)
      end

      # Returns the number of items in the list
      # @see (LegantoSync::ReadingLists::Aspire::ListObject#length)
      def length(item_type = nil)
        item_type ||= :item
        # The item length of a list is the length of the items property,
        # avoiding the need to sum list entry lengths
        item_type == :item ? items.length : super(item_type)
      end

      # Returns a string representation of the List instance (the name)
      # @return [String] the string representation of the List instance
      def to_s
        name || super
      end

      private

      # Retrieves the list details and history from the Aspire JSON API
      # @param uri [String] the reading list object URI (item/list/section)
      # @param factory [LegantoSync::ReadingLists::Aspire::Factory] a factory
      #   returning ReadingListBase subclass instances
      # @param json [Hash] the data containing the properties of the reading
      #   list object from the Aspire JSON API
      # @return [void]
      def init_json_data(uri, factory, json = nil)
        self.api = factory.api
        init_json_defaults
        # Get the list details
        json ||= init_data_list
        if json
          self.name = json['name']
          init_json_items(json['items'])
          init_json_modules(json['modules'])
          init_json_time_period(json['timePeriod'])
        end
        # Return the parsed JSON data from the Aspire list details JSON API
        json
      end

      def init_json_defaults
        # Default values
        self.modules = nil
        self.name = nil
        self.time_period = nil
      end

      def init_json_items(json)
        # A hash mapping item URI to item
        self.items = {}
        return unless json
        json['items'].each { |item| items[item['uri']] = item }
      end

      def init_json_list_details(uri)
        list_id = id_from_uri(uri)
        options = { bookjacket: 1, draft: 1, editions: 1, history: 0 }
        json = api.call("lists/#{list_id}", **options)
        # Get the list history
        self.list_history = api.call("lists/#{list_id}/history")
        # Return the list details
        json
      end

      def init_json_modules(mods)
        return unless mods
        self.modules = mods.map { |m| Module.new(m['uri'], factory, json: m) }
      end

      def init_json_time_period(period)
        self.time_period = if period
                             TimePeriod.new(period['uri'], factory,
                                            json: period)
                           end
      end

      # Sets reading list properties from the Aspire linked data API
      # @return [void]
      def init_linked_data(uri, factory, ld = nil)
        list_data = ld[self.uri]
        init_linked_data_creator(list_data, ld)
        init_linked_data_modules(list_data, ld)
        init_linked_data_owner(list_data, ld)
        init_linked_data_publisher(list_data, ld)
        self.created = get_date(CREATED, list_data)
        self.description = get_property(DESCRIPTION, list_data)
        self.last_published = get_date(LAST_PUBLISHED, list_data)
        self.last_updated = get_date(LAST_UPDATED, list_data)
        self.name = get_property(NAME, list_data) unless name
      end

      def init_linked_data_creator(list_data, ld)
        has_creator = get_property(HAS_CREATOR, list_data, single: false) || []
        self.creator = has_creator.map { |u| factory.get(u, ld: ld) }
      end

      def init_linked_data_modules(list_data, ld)
        return unless modules.nil?
        mods = get_property(USED_BY, list_data, single: false)
        self.modules = mods.map { |u| factory.get(u, ld: ld) } if mods
      end

      def init_linked_data_owner(list_data, ld)
        has_owner = get_property(HAS_OWNER, list_data, single: false) || []
        self.owner = has_owner.map { |u| factory.get(u, ld: ld) }
      end

      def init_linked_data_publisher(list_data, ld)
        published_by = get_property(PUBLISHED_BY, list_data)
        self.publisher = factory.get(published_by, ld: ld)
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
        json ||= init_list_items
        init_digitisation(json)
        init_resource(json)
        self.importance = get_property('importance', json)
        self.library_note = get_property('libraryNote', json)
        self.local_control_number = get_property('lcn', json)
        self.note = get_property('note', json)
        self.student_note = get_property('studentNote', json)
        self.title = get_property('title', json)
      end

      # Returns the length of the list item
      # @see (Aspire::Object::ListBase#length)
      def length(item_type = nil)
        item_type ||= :item
        # List items return an item length of 1 to enable summation of
        #   list/section lengths
        item_type == :item ? 1 : super(item_type)
      end

      # Returns the public (student or general) note
      # @return [String] the student note or general note
      def public_note
        student_note || note
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
        return resource.title || @title if resource
        return library_note if alt == :library_note || alt == :private_note
        return public_note || library_note if alt == :note
        return public_note if alt == :public_note || alt == :student_note
        return uri if alt == :uri
        nil
      end

      # Returns a string representation of the ListItem instance (the citation
      #   title or note)
      # @return [String] the string representation of the ListItem instance
      def to_s
        title(:public_note).to_s
      end

      private

      # Returns the digitisation request JSON data if available, nil if not
      # @param json [Hash] the JSON API data
      # @return [void]
      def init_digitisation(json)
        dig_json = json ? json['digitisation'] : nil
        dig_ld = nil
        self.digitisation = if dig_json || dig_ld
                              Digitisation.new(json: dig_json, ld: dig_ld)
                            end
      end

      # Returns the list of JSON API list items from the parent list
      # @return [Array<Hash>] the list items, or nil if none are available
      def init_list_items
        owner = parent_list
        owner && owner.items ? owner.items[uri] : nil
      end

      # Sets the resource
      # @param json [Hash] the parsed JSON resource data
      # @return nil
      def init_resource(json)
        res_json = json ? json['resource'] : nil
        if res_json.is_a?(Array)
          res_json = res_json.empty? ? nil : res_json[0]
          puts("WARNING: used first resource of #{res_json}") if res_json
        end
        self.resource = factory.get(res_json['uri'], json: res_json) if res_json
        # resource_json = json ? json['resource'] : nil
        # resource_uri = get_property('http://purl.org/vocab/resourcelist/schema#resource', item_ld)
        # resource = resource_json # || resource_uri ? factory.get(resource_uri, json: resource_json, ld: ld) : nil
      end
    end

    # Represents a reading list section in the Aspire API
    class ListSection < ListBase
      include Properties

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
        self.description = get_property(DESCRIPTION, section_ld)
        self.name = get_property(NAME, section_ld)
      end

      # Returns a string representation of the ListSection instance (the section
      #   name)
      # @return [String] the string representation of the ListSection instance
      def to_s
        name || super
      end
    end
  end
end