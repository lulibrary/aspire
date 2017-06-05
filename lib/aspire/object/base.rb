require 'cgi'

require 'loofah'

require 'aspire/util'

module Aspire
  module Object
    # The base class for Aspire API objects
    class Base
      # Aspire properties containing HTML markup will have the markup stripped
      #   if STRIP_HTML = true"#{without format suffix (.html, .json etc.)}"
      STRIP_HTML = true

      include Aspire::Util

      # @!attribute [rw] factory
      #   @return [Aspire::Object::Factory] the factory for creating
      #     Aspire::Object instances
      attr_accessor :factory

      # @!attribute [rw] uri
      #   @return [String] the URI of the object
      attr_accessor :uri

      # Initialises a new APIObject instance
      # @param uri [String] the URI of the object
      # @param factory [Aspire::Object::Factory] the factory for creating
      #   Aspire::Object instances
      # @return [void]
      def initialize(uri, factory)
        self.factory = factory
        self.uri = uri
      end

      # Returns a Boolean property value
      # @param property [String] the property name
      # @param data [Hash] the data hash containing the property
      #   (defaults to self.ld)
      # @param single [Boolean] if true, return a single value, otherwise return
      #   an array of values
      # @return [Boolean, Array<Boolean>] the property value(s)
      def get_boolean(property, data, single: true)
        get_property(property, data, single: single) do |value, _type|
          value ? true : false
        end
      end

      # Returns a DateTime instance for a timestamp property
      # @param property [String] the property name
      # @param data [Hash] the data hash containing the property (defaults to
      #   self.ld)
      # @param single [Boolean] if true, return a single value, otherwise return
      #   an array of values
      # @return [DateTime, Array<DateTime>] the property value(s)
      def get_date(property, data, single: true)
        get_property(property, data, single: single) do |value, _type|
          DateTime.parse(value)
        end
      end

      # Returns the value of a property
      # @param property [String] the property name
      # @param data [Hash] the data hash containing the property
      #   (defaults to self.data)
      # @param is_url [Boolean] if true, the property value is a URL
      # @param single [Boolean] if true, return a single value, otherwise return
      #   an array of values
      # @return [Object, Array<Object>] the property value(s)
      # @yield [value, type] passes the value and type to the block
      # @yieldparam value [Object] the property value
      # @yieldparam type [String] the type of the property value
      # @yieldreturn [Object] the transformed property value
      def get_property(property, data, is_url: false, single: true, &block)
        values = data ? data[property] : nil
        if values.is_a?(Array)
          values = values.map do |value|
            get_property_value(value, is_url: is_url, &block)
          end
          single ? values[0] : values
        else
          value = get_property_value(values, is_url: is_url, &block)
          single ? value : [value]
        end
      end

      # Returns a string representation of the APIObject instance (the URI)
      # @return [String] the string representation of the APIObject instance
      def to_s
        uri.to_s
      end

      protected

      # Retrieves and transforms the property value
      # @param value [String] the property value from the Aspire API
      # @param is_url [Boolean] if true, the property value is a URL
      # @yield [value, type] Passes the property value and type URI to the block
      # @yieldparam value [Object] the property value
      # @yieldparam type [String] the property value's type URI
      # @yieldreturn [Object] the transformed property value
      # @return [String] the property value
      def get_property_value(value, is_url: false)
        # Assume hash values are a type/value pair
        if value.is_a?(Hash)
          type = value['type']
          value = value['value']
        else
          type = nil
        end
        # Apply transformations to string properties
        value = transform(value, is_url: is_url) if value.is_a?(String)
        # If a block is present, return the result of the block
        return yield(value, type) if block_given?
        # Otherwise return the value
        value
      end

      # Removes HTML markup from property values
      # @param value [String] the property value from the Aspire API
      # @param is_url [Boolean] if true, the property value is a URL
      # @return [String] the property value
      def transform(value, is_url: false)
        if is_url
          # Remove HTML-escaped encodings from URLs without full HTML-stripping
          CGI.unescape_html(value)
        elsif STRIP_HTML
          # Strip HTML preserving block-level whitespace
          # - Loofah seems to preserve &amp; &quot; etc. so we remove these with
          #   CGI.unescape_html
          text = CGI.unescape_html(Loofah.fragment(value).to_text)
          # Collapse all runs of whitespace to a single space
          text.gsub!(/\s+/, ' ')
          # Remove leading and trailing whitespace
          text.strip!
          # Return the transformed text
          text
        else
          # Return value as-is
          value
        end
      end
    end
  end
end