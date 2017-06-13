module Aspire
  # Aspire linked data API property names
  module Properties
    AIISO_CODE = 'http://purl.org/vocab/aiiso/schema#code'.freeze
    AIISO_NAME = 'http://putl.org/vocab/aiiso/schema#name'.freeze
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
end