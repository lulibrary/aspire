require 'aspire/cli/command'
require 'aspire/enumerator/report_enumerator'
require 'aspire/util'
require 'logglier'
require 'dotenv'

module Aspire
  module CLI

    class CacheBuilder < Command

      def execute

        unless (env_file.nil? || env_file.empty?)
          Dotenv.load(env_file)
        end

        @json_api = json_api
        @linked_data_api = linked_data_api
        @logger = create_logger log_to_file?
        @cache_path = ENV['ASPIRE_CACHE_PATH']
        @list_report = ENV['ASPIRE_LIST_REPORT']
        @mode = ENV['ASPIRE_CACHE_MODE']
        @mode = @mode.nil? || @mode.empty? ? 0o700 : @mode.to_i(8)
        cache = Aspire::Caching::Cache.new(@linked_data_api, @json_api, @cache_path,
                                           logger: @logger)
        @builder = Aspire::Caching::Builder.new(cache)

        if list_uri.nil? || list_uri.empty?

          raise ArgumentError if privacy_control.nil? || privacy_control.empty?

          puts "Caching all lists that match arguments"

          lists = list_enumerator time_period_list, status, privacy_control

          @builder.build(lists)

          puts "Finished caching all lists that match arguments"

        else
          puts "Caching list #{list_uri}"
          @builder.write_list(list_uri)
          puts "Finished caching list"
        end

      end

      private

      def list_enumerator(time_periods=nil, status=nil, privacy_control=nil)

        filters = []

        if time_periods.nil? || time_periods.empty? || time_periods == ['']
          time_periods = [nil, '']
        end

        filters.push(proc { |row| time_periods.include?(row['Time Period']) })

        unless status.nil? || status.empty?
          filters.push(proc { |row| row['Status'].to_s.start_with?(status) })
        end

        unless privacy_control.nil? || status.empty?
          filters.push(proc { |row| row['Privacy Control'] == privacy_control })
        end

        Aspire::Enumerator::ReportEnumerator.new(@list_report, filters)
            .enumerator
      end

      def json_api
        @api_available = ENV['ASPIRE_API_AVAILABLE'] == 'true'
        @api_client_id = ENV['ASPIRE_API_CLIENT_ID']
        @api_secret = ENV['ASPIRE_API_SECRET']
        @tenant = ENV['ASPIRE_TENANT']
        Aspire::API::JSON.new(@api_client_id, @api_secret, @tenant,
                              **api_opts)
      end

      def api_opts
        @ssl_ca_file = ENV['SSL_CA_FILE']
        @ssl_ca_path = ENV['SSL_CA_PATH']
        {
            ssl_ca_file: @ssl_ca_file,
            ssl_ca_path: @ssl_ca_path
        }
      end

      def linked_data_api
        @api_available = ENV['ASPIRE_API_AVAILABLE'] == 'true'
        @linked_data_root = ENV['ASPIRE_LINKED_DATA_ROOT']
        @tenant = ENV['ASPIRE_TENANT']
        @tenancy_host_aliases = ENV['ASPIRE_TENANCY_HOST_ALIASES'].to_s.split(';')
        @tenancy_root = ENV['ASPIRE_TENANCY_ROOT']
        Aspire::API::LinkedData.new(@tenant,
                                    linked_data_root: @linked_data_root,
                                    tenancy_host_aliases: @tenancy_host_aliases,
                                    tenancy_root: @tenancy_root,
                                    **api_opts)
      end

      def create_logger log_to_file

        @log_file = ENV['ASPIRE_LOG']

        if log_to_file
          logger = Logger.new("| tee #{@log_file}") # @log_file || STDOUT)
          logger.datetime_format = '%Y-%m-%d %H:%M:%S'
          logger.formatter = proc do |severity, datetime, _program, msg|
            "#{datetime} [#{severity}]: #{msg}\n"
          end
          return logger
        end

        Logglier.new("https://logs-01.loggly.com/inputs/#{ENV['LOGGLIER_TOKEN']}/tag/#{ENV['LOGGLIER_TAG']}/", :threaded => true, :format => :json)
      end

    end

  end
end