module Aspire

  # Selects the primary email address for a user based on rules read from a configuration file
  class EmailSelector

    # @!attribute [rw] config
    #   @return [Hash] the configuration parameter hash
    attr_accessor :config

    # @!attribute [rw] map
    #   @return [Hash<String, String>] a map of email addresses to the canonical (institutional) email address
    attr_accessor :map

    # Initialises a new EmailSelector instance
    # @param filename [String] the name of the configuration file
    # @param map_filename [String] the name of a CSV file containing all known email addresses for a user
    # @return [void]
    def initialize(filename = nil, map_filename = nil)
      self.load_config(filename)
      self.load_map(map_filename)
    end

    # Clears the email map
    # @return [void]
    def clear
      self.map.clear
    end

    # Returns the preferred email address from a list of addresses based on the configuration rules.
    # The email addresses are first matched as provided. If no matches are found, the substitution rules from the
    # configuration are applied and the matching process is repeated on the substituted values. If no matches are
    # found after substitution, the first email in the list is returned.
    # @param emails [Array<String>] the list of email addresses
    # @param use_map [Boolean] if true, use the email map to resolve addresses
    # @param user [LegantoSync::ReadingLists::Aspire::User] the user supplying the list of email addresses
    # @return [String] the preferred email address
    def email(emails = nil, use_map: true, user: nil)
      emails = user.email if emails.nil? && !user.nil?
      # Check the emails as supplied
      result = email_domain(emails)
      return result unless result.nil?
      # If no match was found, apply substitutions and check again
      emails = email_sub(emails)
      result = email_domain(emails)
      # If no match was found after substitutions, check against the email address map
      result = email_map(emails) if result.nil? && use_map
      # If there is still no match, take the first email in the list
      result = emails[0] if result.nil?
      # Return the result
      result
    end

    # Loads the configuration from the specified file
    # @param filename [String] the name of the configuration file
    # @return [void]
    def load_config(filename = nil)
      self.config = {
          domain: [],
          sub: []
      }
      return if filename.nil? || filename.empty?
      CSV.foreach(filename, { col_sep: "\t" }) do |row|
        action = row[0] || ''
        action.strip!
        action.downcase!
        # Skip empty lines and comments
        next if action.nil? || action.empty? || action[0] == '#'
        case action
          when '!', 'domain'
            domain = row[1] || ''
            domain.downcase!
            self.config[:domain].push(domain) unless domain.nil? || domain.empty?
          when '$', 'sub'
            regexp = row[1]
            replacement = row[2] || ''
            self.config[:sub].push([Regexp.new(regexp), replacement]) unless regexp.nil? || regexp.empty?
        end
      end
      nil
    end


    # Loads email mappings from the specified file
    def load_map(filename = nil)
      self.map = {}
      return if filename.nil? || filename.empty?
      delim = /\s*;\s*/
      File.foreach(filename) do |row|
        row.rstrip!
        emails = row.rpartition(',')[2]
        next if emails.nil? || emails.empty?
        # Get all the emails for this user
        emails = emails.split(delim)
        # No need to map a single email to itself
        next if emails.length < 2
        # Get the primary (institutional) email
        primary_email = email(emails, use_map: false)
        # Map all emails to the primary email
        emails.each { |e| self.map[e] = primary_email unless e == primary_email }
      end
    end

    protected

    # Returns the first email address in the list with a domain matching one of the preferred domains from the
    # configuration. The preferred domains are searched in the order they appear in the configuration file, so
    # they should appear in the file in order of preference.
    # @param emails [Array<String>] the list of email addresses
    # @return [String] the preferred email address
    def email_domain(emails)
      domains = self.config[:domain]
      unless domains.empty?
        domains.each do |domain|
          matches = emails.select { |email| email.end_with?(domain) }
          return matches[0] unless matches.empty?
        end
      end
      nil
    end

    # Returns the canonical (institutional) email address for the first address which exists in the email map
    # @param emails [Array<String>] the list of email addresses
    # @return [String] the canonical email address
    def email_map(emails)
      emails.each do |e|
        result = self.map[e]
        unless result.nil? || result.empty?
          return result
        end
      end
      nil
    end

    # Returns a copy of the email list parameter with substitutions applied to each email
    # @param emails [Array<String>] the list of email addresses
    # @return [Array<String>] the list of modified email addresses
    def email_sub(emails)
      subs = self.config[:sub]
      if subs.nil? || subs.empty?
        emails
      else
        emails.map do |email|
          # Apply substitutions to and return a copy of the email
          email_sub = email.slice(0..-1)
          subs.each { |sub| email_sub.gsub!(sub[0], sub[1]) }
          email_sub
        end
      end
    end

  end

end
