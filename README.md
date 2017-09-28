# Aspire

This gem provides tools for working with Talis Aspire APIs to manage reading
lists. It implements a data model for the common API objects (list, section,
item, resource etc.) and provides a mechanism for caching API data for offline
access.

## Contents

* [Installation](#installation)
* [Usage](#usage)
  * [Overview](#usage-overview)
  * [APIs](#usage-apis)
    * [Linked Data API](#usage-apis-linked-data)
    * [Authenticated (JSON) API](#usage-apis-json)
  * [Caching](#caching)
    * [Cache](#caching-cache)
    * [Cache Builder](#caching-cache-builder)
      * [Report Enumerator](#caching-cache-builder-enum)
      * [Cache Builder](#caching-cache-builder-cache-builder)
      * [Caveats](#caching-cache-builder-caveats)
   * [Data Model](#model)
     * [Overview](#model-overview)
     * [User Profiles](#model-user-profiles)
     * [Factory](#model-factory)
     * [List](#model-list)
       * [Iterating over lists and sections](#model-list-iter)
       * [List Properties](#model-list-properties)
       * [ListSection Properties](#model-list-section-properties)
       * [ListItem Properties](#model-list-item-properties)
     * [Resource](#model-resource)
       * [Basic Properties](#model-resource-basic)       
       * [Linked Resource Properties](#model-resource-linked)
     * [Digitisation](#model-digitisation)
     * [Module](#model-module)
     * [TimePeriod](#model-timeperiod)
     * [User](#model-user)
   * [Implementation Notes](#implementation)
     * [Preserving List Structure](#implementation-structure)
* [Development](#development)
* [Contributing](#contributing)
* [License](#license)
            
## <a name="installation"></a>Installation

Add this line to your application's Gemfile:

```ruby
gem 'aspire'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install aspire

## <a name="usage"></a>Usage

### <a name="usage-overview"></a>Overview

This gem provides tools for working with the Talis Aspire
[Linked Data API](https://support.talis.com/hc/en-us/articles/205860451) and the
newer [Authenticated (JSON) APIs](http://docs.talisrl.apiary.io/).

To use the Authenticated (JSON) APIs, you will need to request an API key and
secret from Talis
([more](https://support.talis.com/hc/en-us/articles/208221125)).

### <a name="usage-apis"></a>APIs
Credentials, tenancy URLs and other client-specific details are encapsulated
by API objects which are passed to other classes.

#### <a name="usage-apis-linked-data"></a>Linked Data API

To create a Linked Data API instance:
```ruby
require 'aspire'

# Create and configure a logger if required, or pass nil to disable logging
require 'logger'
logger = Logger.new(STDOUT)

# Set the timeout in seconds for API calls, or 0 to disable (wait indefinitely).
# Large lists (several hundred items) may take up to 30 seconds so adjust this
# according to your requirements. 
timeout = 10

# Tenancy configuration
# - these settings specify the base components of resource URIs; all are
#   optional and default to values derived from the tenancy code

# linked_data_root is the root URI of URIs returned in linked data responses
#   (defaults to https://<tenancy-code>.myreadinglists.org)
linked_data_root = 'https://myinstitution.myreadinglists.org'

# tenancy_host_aliases is a list of host name aliases which may appear in
# resource URIs
tenancy_host_aliases = ['resourcelists.myinstitution.ac.uk']

# tenancy_root is the canonical root URI of the tenancy
#   (defaults to https://<tenancy_code>.rl.talis.com)
tenancy_root = 'https://myinstitution.rl.talis.com'

# Create the Linked Data API instance
# - replace 'tenancy_code' with the appropriate value for your Aspire tenancy,
#   e.g. 'myinstitution'
ld_api = Aspire::API::LinkedData('tenancy_code',
                                 linked_data_root: linked_data_root,
                                 tenancy_host_aliases: tenancy_host_aliases,
                                 tenancy_root: tenancy_root, 
                                 logger: logger, timeout: timeout)                                 
```

#### <a name="usage-apis-json"></a>Authenticated (JSON) API

To create an Authenticated (JSON) API instance:

```ruby
require 'aspire'

# Set the logger and timeout as above
logger = ...
timeout = ...

# Create the JSON API instance
# - replace 'api_client_id', 'api_secret' and 'tenancy_code' with appropriate
#   values for your Aspire tenancy 
json_api = Aspire::API::JSON.new('api_client_id', 'api_secret', 'tenancy_code',
                                 logger: logger, timeout: timeout)

# Call a JSON API endpoint
json_api.call()
 
```

### <a name="caching"></a>Caching

#### <a name="caching-cache"></a>Cache

The `Aspire::Caching::Cache` class mediates access to the Aspire APIs,
storing API responses on disk and returning the cached copies on subsequent
accesses. This is intended to serve as both a means of backing up Aspire data
locally and as a means of speeding up slow API calls.

```ruby
require 'aspire'

# Create Linked Data and JSON API instances
ld_api = Aspire::API::LinkedData.new(...)
json_api = Aspire::API::JSON.new(...)

# Create the cache at the specified path
#
# The following optional keyword arguments are accepted:
# - clear:  if true, remove and recreate the cache path
#           (default: false)
# - logger: a Logger instance for logging, or nil to disable
#           (default: nil)
# - mode:   the octal file permissions for the cache directory
#           (default: 0o0750)
#
cache = Aspire::Caching::Cache.new(ld_api, json_api, '/path/to/cache/root',
                                   clear: false,
                                   logger: Logger.new(STDOUT),
                                   mode: 0o0700)
``` 

The cache is mainly intended for internal use by the data model but can be
used by clients of this gem if required.

```ruby
# An Aspire linked data URI resource
uri = 'https://myinstitution.rl.talis.com/lists/FFCB71DE-EE3A-1D42-BAAE-9CA9CFF0EE72'

# Read an Aspire linked data URI, returning the parsed JSON data as a Hash
# - use_api:   if true, when a URI is not already in the cache, read data from
#              the Aspire API and write it to the cache
#              (default: true)
# - use_cache: if true, read data from the cache before trying the Aspire API
#              (default: true)
# - json:      if true, read data from the JSON API, otherwise use the Linked
#              Data API
#              (default: false)
data = cache.read(uri, json: false, use_api: true, use_cache: true) \
         do |data, entry, from_cache, json|
           # The block is called only if data is read from the cache or API
           # The parameters are:
           # - data       = the parsed JSON data for the resource
           # - entry      = an ```Aspire::Caching::CacheEntry``` instance
           #                representing the cached entry (for internal use)
           # - from_cache = true if the data was retrieved from the cache,
           #                false if from the API
           # - json       = true if the data is from the JSON API,
           #                false if from the Linked Data API
         end

# Remove a resource from the cache, returning the cached JSON data as a Hash
# - remove_children: if true, remove 
data = cache.remove(uri, force: true, remove_children: true) \
         do |data, entry|
           # The block is called only if cached data exists
           # The parameters are:
           # - data  = the parsed JSON data for the cached resource
           # - entry = an ```Aspire::Caching::CacheEntry``` instance representing
           #           the cached entry (for internal use)
         end
 
# Delete the cache contents but not the root path
cache.clear

# Delete the cache root path and contents
cache.delete

# Return true if the cache root path is empty, false otherwise
cache.empty?
```

#### <a name="caching-cache-builder"></a>Cache Builder

The `Aspire::Caching::Builder` class constructs an offline cache of Linked Data
and JSON API data.
 
Given an enumerator of list IDs, the cache builder downloads the JSON and Linked
Data API data for each list and recursively follows all URIs in the linked data
until every entity has been retrieved.  

The list enumerator is expected to be an instance of
`Aspire::Enumerator::ReportEnumerator`, which parses a file as a CSV and yields
the parsed row. When parsing an Aspire "All Lists" report, the parsed CSV row is
yielded as a Hash containing the list URI at key "List Link", so the cache
builder expects this from the enumerator. If you're using a custom enumerator
rather than the `ReportEnumerator`, you should yield the list URI as follows:

```ruby 
    yielder << { 'List Link' => '<list-URI>' }
```

##### <a name="caching-cache-builder-enum"></a>Report Enumerator

A list enumerator is created from an Aspire "All Lists" report CSV as follows:

```ruby

    # Optionally define one or more filters to control which lists are selected.
    # Each filter is a Proc instance which accepts the Hash or Array from the 
    # CSV parser and returns true to include the list or false to ignore it.
    # All filters must return true for the list to be included.
    filters = [
      proc { |row| row['Status'] == 'Published' },
      proc { |row| row['Privacy'] == 'Public' },
      proc { |row| row['Time Period'] == '2017-18' }
    ]
    
    # The filename of a downloaded Aspire "All Lists" report in CSV format
    filename = '/path/to/all_lists.csv'
    
    # Create the report enumerator
    lists = Aspire::Enumerator::ReportEnumerator(filename, filters)
```

##### <a name="caching-cache-builder-cache-builder"></a>Cache Builder

```ruby
    # Create a Cache
    cache = Aspire::Caching::Cache.new(...)
    
    # Create a list enumerator
    lists = Aspire::Enumerator::ReportEnumerator(...)
    
    # Create a cache Builder
    builder = Aspire::Caching::Builder.new(cache)
    
    # Build the cache
    # - clear: if true, clear the cache before building
    builder.build(lists, clear: true)
```

##### <a name="caching-cache-builder-caveats"></a>Caveats

1. The current implementation is slow to run (partly due to the slow speed of
the JSON API for large lists) and memory-intensive (due to the recursive
processing of referenced resources, which can result in deeply-nested method
call stacks). A parallelised approach would help to improve this. 

2. The current implementation doesn't reliably handle resuming an interrupted
build and may skip data. Because of this, it's **strongly recommended** to
always build a new cache with the `clear: true` flag.

3. Due to the previous two points (slow run speed and inability to resume an
interrupted build), and the possibility that network and other problems may
break a long-running build, it's recommended to build a number of small caches
rather than a single cache of everything. Filters passed to the
`Aspire::Enumerator::ReportEnumerator` can limit the size of the cache.
For example, you may want to build one cache per time period.   

4. The cache builder can only download publicly-visible lists (private lists
require authentication by the owner), so you should always include a filter for
this:

```ruby
    filters = [
      proc { |row| row['Privacy'] == 'Public' },
      # other filters
    ]
```
### <a name="model"></a>Data Model

#### <a name="model-overview"></a>Overview

The data model provides a set of classes representing common resources in the
Talis Aspire APIs, such as lists, list sections, list items and bibliographic
resources.

Model instances are retrieved through a factory which uses a combination of the
Linked Data API, Authenticated (JSON) API and the Aspire "All User Profiles"
report to construct the models.

#### <a name="model-user-profiles"></a>User Profiles

User profiles referenced by the Aspire Linked Data API URIs are not directly
available through the Linked Data or JSON APIs, so the `Aspire::Object::Factory`
class accepts a Hash of user data of the form:

```ruby
users = {
  'https://myinstitution.rl.talis.com/users/ABCD1234-FE98-DC76-BA54-54321FEBACD0' => {
    email: 'anne.onymouse@myinstution.ac.uk',
    firstName: 'Anne',
    role: ['List publisher', 'List creator'],
    surname: 'Onymous',
    uri: 'https://myinstitution.rl.talis.com/users/ABCD1234-FE98-DC76-BA54-54321FEBACD0'
  }
}
```

The data hash follows the JSON format documented by the
[Aspire JSON API](http://docs.talisrl.apiary.io/#reference/catalog/catalog-record-based-on-isbn/get-user-profile)

The `Aspire::UserLookup` class provides a simple means of loading an Aspire
"All User Profiles" report CSV.

```ruby
require 'aspire'

users = Aspire::UserLookup.new(filename: '/path/to/all_user_profiles.csv')
user = users['https://myinstitution.rl.talis.com/users/ABCD1234-FE98-DC76-BA54-54321FEBACD0']
```

#### <a name="model-factory"></a>Factory

The `Aspire::Object::Factory` class returns data model instances. Data is
read from an Aspire API data cache (see *Cache* above) except for user data,
which is supplied by a Hash mapping user URIs to a Hash of user data (see
*User Profiles* above).

```ruby
require 'aspire'

# Create a cache
cache = Aspire::Caching::Cache.new(...)

# Create a user hash from an Aspire "All User Profiles" report CSV
users = Aspire::UserLookup.new(filename: '/path/to/all_user_profiles.csv')

# Create a factory
factory = Aspire::Object::Factory.new(cache, users)

# Get a model instance by its URI
uri = 'https://myinstitution.rl.talis.com/lists/FFCB71DE-EE3A-1D42-BAAE-9CA9CFF0EE72'
list = factory.get(uri)
```

#### <a name="model-list"></a>List

`Aspire::Object::List` represents a resource list, composed of an
ordered sequence of `Aspire::Object::ListSection` and `Aspire::Object::ListItem`
instances. The ordering of list entries and the nested list structure are both
preserved from Aspire (see *Implementation Notes* for details).

`Aspire::Object::ListSection` represents a resource list section, composed of
an ordered sequence of `Aspire::Object::ListSection` and
`Aspire::Object::ListItem` instances (nested subsections and list items).

`Aspire::Object::ListItem` represents a single list item.

##### <a name="model-list-iter"></a>Iterating over lists and sections

`List` and `ListSection` act as ordered containers for child `ListSection` and
`ListItem` instances. Both classes support various iterators over their child
and parent objects:

```ruby
require 'aspire'

# Create a factory
factory = Aspire::Object::Factory.new(...)

# Get a list
list = factory.get(...)

# Iterate over the top-level list contents in list order
list.each { |item| # item is a ListSection or ListItem instance }

# Iterate over all ListItem instances in list order
# Nested list sections are iterated in depth-first order
list.each_item { |item| # item is a ListItem instance }

# Iterate over all ListSection instances in list order
# Nested list sections are iterated in depth-first order
list.each_section { |section| # section is a ListSection instance }

# Get a list of all ListItem instances in list order
# Nested list sections are iterated in depth-first order
items = list.items

# Get a list of all ListSection instances in list order
# Nested list sections are iterated in depth-first order
sections = list.sections

# Get the number of top-level list items (sections and items)
length = list.length(:entry)

# Get the number of ListItem instances
# Both forms are equivalent
length = list.length
length = list.length(:item)

# Get the number of top-level ListSection instances
length = list.length(:section)

# Get the parent list of a List, ListSection or ListItem
parent_list = list.parent_list

# Get the immediate parent section of a ListSection or ListItem
parent_section = list.parent_section

# Get a list of parent sections of a ListSection or ListItem in nearest ancestor
# first order
parent_sections = list.parent_sections

# Get a list of parent items (ListSection and List) of a ListSection or ListItem
# in nearest ancestor first order
parents = list.parents

# Get a list of parent items matching the supplied classes
parents = list.parents(List, ListSection)

# Get a list of parent items where the supplied block returns true
parents = list.parents { |item| item.is_a?(ListItem) }
```

##### <a name="model-list-properties"></a>List properties

```ruby

      # Creation timestamp of the list as a DateTime
      list.created

      # Reading list creators as an array of Aspire::Object::User
      list.creator

      # Description of the list
      list.description

      # List items as a hash of Aspire::Object::ListItem indexed by item URI
      list.items

      # Timestamp of the most recent list publication as a DateTime
      list.last_published

      # Timestamp of the most recent list update as a DateTime
      list.last_updated

      # Modules referencing this list as an array of Aspire::Object::Module
      list.modules

      # Reading list name
      list.name
      list.to_s
      
      # List owner as an Aspire::Object::User
      list.owner

      # List publisher as an Aspire::Object::User
      list.publisher

      # Period covered by the list as an Aspire::Object::TimePeriod
      list.time_period
```

##### <a name="model-list-section-properties"></a>ListSection properties

```ruby
    # Section description
    section.description
    
    # Section name
    section.name
    section.to_s
```

##### <a name="model-list-item-properties"></a>ListItem properties

```ruby
      # Digitisation details for the item as an Aspire::Object::Digitisation
      item.digitisation

      # Importance of the item
      item.importance

      # Private library note for the item
      item.library_note

      # Identifier of the resource in the local library management system
      item.local_control_number

      # General public note for the item
      item.note

      # Student note if available, otherwise the general public note
      item.public_note
      
      # Resource for the item as an Aspire::Object::Resource
      item.resource

      # Public student note for the item
      item.student_note

      # Title of the item (i.e. the title of the associated resource)
      item.title
      # The resource title is always returned if it is available.
      # If there is no associated resource, an alternative can be specified;
      # the default is to return nil.
      item.title(:library_note)  # returns library_note
      item.title(:note)          # returns public_note || library_note
      item.title(:public_note)   # returns public_note
      item.title(:uri)           # returns the item URI
```

#### <a name="model-resource"></a>Resource

`Aspire::Object::Resource` represents the bibliographic item (book/chapter,
journal/article, online resource etc.) referenced by a list item.

Resources may be linked to other resources. For example, a book chapter resource
may be linked to its parent book, or a journal article to its parent journal.
 
##### <a name="model-resource-basic"></a>Basic Properties

```ruby
      # Get the resource from the list item
      resource = item.resource
      
      # List of authors of the resource as an array of strings
      resource.authors

      # Book jacket image URL
      resource.book_jacket_url

      # Date of publication as a string
      resource.date

      # DOI for the resource
      resource.doi

      # Edition
      resource.edition

      # true if edition data is available, false if not
      resource.edition_data

      # Electronic ISSN for the resource
      resource.eissn

      # Child resources as an array of Aspire::Object::Resource
      # - e.g. the chapters contained of a book or articles of a journal
      resource.has_part

      # Parent resources as an array of Aspire::Object::Resource
      # - e.g. the book containing a chapter or journal containing an article
      resource.is_part_of

      # 10-digit ISBN for the resource
      resource.isbn10

      # 13-digit ISBN for the resource
      resource.isbn13

      # List of ISBNs for the resource
      resource.isbns

      # ISSN for the resource
      resource.issn

      # Issue
      resource.issue

      # Issue date as a string
      resource.issued

      # true if this is the latest edition, false otherwise
      resource.latest_edition

      # Local control number in the library catalogue
      resource.local_control_number

      # true if this is an online resource, false otherwise
      resource.online_resource

      # Page range
      resource.page

      # End page
      resource.page_end

      # Start page
      resource.page_start

      # Place of publication
      resource.place_of_publication

      # Publisher
      resource.publisher

      # Title of the resource
      resource.title

      # Type of the resource
      resource.type

      # URL of the resource
      resource.url

      # Volume
      resource.volume
```

##### <a name="model-resource-linked"></a>Linked Resource Properties

Where resources are linked to other resources (e.g. chapters to books or
articles to journals) a number of shortcut properties are available. These
methods can be called on either the child or parent resource.

```ruby
    # Article title for a journal or article resource
    resource.article_title
    
    # Book title for a book or chapter resource
    resource.book_title
    
    # Book chapter title for a book or chapter resource
    resource.chapter_title
    
    # Article or chapter title if available, otherwise the resource
    # title
    resource.citation_title
    
    # Journal title for an article or journal resource
    resource.journal_title
    
    # Parent resource's title (book or journal title)
    resource.part_of_title
    
    # Child resource's title (article or chapter title)
    resource.part_title
    
    # Any resource property can be prefixed with "citation_"
    # In this case, if the resource property is not set, the property of the
    # parent resource is returned instead if applicable.
    resource.citation_title   # Returns resource.title or the parent title
    resource.citation_isbn10  # Returns resource.isbn10 or the parent isbn10    
```

#### <a name="model-digitisation"></a>Digitisation

`Aspire::Object::Digitisation` represents a Talis Digitised Content request
associated with a list item.

```ruby
    # Get the digitisation request details from the list
    digitisation = list.digitisation
    
    # Digitisation bundle ID
    digitisation.bundle_id
    
    # Digitisation request ID
    digitisation.request_id
    
    # Digitisation request status
    digitisation.request_status
```

#### <a name="model-module"></a>Module

`Aspire::Object::Module` represents a course module associated with a list.

```ruby
    # Get the modules from the list
    modules = list.modules
    module = modules[0]

    # Module code
    module.code

    # Module name
    module.name
```

#### <a name="model-timeperiod"></a>TimePeriod

`Aspire::Object::TimePeriod` represents the time period covered by a list.

```ruby
    # Get the time period from the list
    period = list.time_period
    
    # true if the list is currently within the time period, false otherwise
    period.active
    
    # End of the period as a Date
    period.end_date
    
    # Start of the period as a Date
    period.start_date
        
    # Title of the time period (e.g. "Winter Term 2016/17")
    period.title
```

#### <a name="model-user"></a>User

`Aspire::Object::User` represents an Aspire user profile returned from the
[User Profile JSON API](http://docs.talisrl.apiary.io/reference/users/user-profile).

```ruby
    # Get the list owner from the list
    user = list.owner
    
    # User first and last names
    user.first_name
    user.surname
    
    # User email addresses as an array of strings
    user.email
    
    # User roles as an array of strings
    user.role
```

#### Command-Line

### <a name="implementation"></a>Implementation Notes

#### <a name="implementation-structure"></a>Preserving List Structure

The Aspire Authenticated (JSON) API provides convenient access to resource list
items but does not preserve the ordering of list items, and supplies only the
immediately-enclosing section.

However, the Linked Data API includes sequencing data properties with keys of
the form `http://www.w3.org/1999/02/22-rdf-syntax-ns#_N` (where `N` is the
ordinal position of the item or section within its parent collection) whose
values are the URIs of the item or section. These properties allow the list
order to be recreated in the data model, and the nested section structure to be
recreated by recursively following the section URIs.

Consider the list:
* Item 1
* Section 2
   * Item 2.1 
   * Item 2.2 
   * Item 2.3
* Section 3
   * Item 3.1
   * etc. 
   
The Linked Data API response for the list will contain something like:  
```json
{
  “http://myinstitution.myreadinglists.org/lists/A56880F3-10B3-45EC-FD16-D29D0198AEE3": {

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_1": [ {
      "value": "http://myinstitution.myreadinglists.org/items/BEC9F28E-0663-751A-08D5-4729CBDD5991",
      "type": "uri"
    } ],

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2": [ {
      "value": "http://myinstitution.myreadinglists.org/sections/5B357D24-3F3B-35FF-6EEC-3FD8964B523C",
      "type": "uri"
    } ],

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_3": [ {
      "value": "http://myinstitution.myreadinglists.org/sections/96DACBC0-EC2F-03CD-9A50-70082D2C1D83",
      "type": "uri"
    } ]
  }
}
```

The Linked Data API response for "Section 2" will contain something like:
```json
{
  "http://myinstitution.myreadinglists.org/sections/5B357D24-3F3B-35FF-6EEC-3FD8964B523C": {

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_1": [ {
      "value": "http://myinstitution.myreadinglists.org/items/B51508AB-5166-5CD5-30D5-9DF77BA461BB",
      "type": "uri"
    } ],

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_2": [ {
      "value": "http://myinstitution.myreadinglists.org/items/AD6F8D90-7EB6-9721-0FDE-3C26F7FA932C",
      "type": "uri"
    } ],

    "http://www.w3.org/1999/02/22-rdf-syntax-ns#_3": [ {
      "value": "http://myinstitution.myreadinglists.org/items/11234123-83EA-D529-8DA1-42BAAA64BF6F",
      "type": "uri"
    } ]
  }
}
```

The data model for a list is built as follows:
1. get the Authenticated (JSON) API data for the list and build a Hash mapping
  item URI to a ListItem instance
2. get the Linked Data API data for the list
3. build a List instance
4. for each sequencing data property in the list data
      * if the value is an item URI, get the ListItem instance from the items Hash
      * if the value is a section URI, build a ListSection instance (this
        recursively creates subsections and list items)
      * add the instance to the List's children at position `N`
        
## <a name="development"></a>Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## <a name="contributing"></a>Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lulibrary/aspire. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## <a name="license"></a>License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

