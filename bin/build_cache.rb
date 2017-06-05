#!/usr/bin/env ruby

require 'logger'
require 'optionparser'

require 'aspire/api/json'
require 'aspire/api/linked_data'
require 'aspire/caching/builder'
require 'aspire/enumerator/list_report_enumerator'

# Maps the command-line field abbreviation to a named field in the All Lists CSV
fields = {
  h: 'Hierarchy Code',
  l: 'List Link',
  t: 'Time Period',
  u: 'Last Updated'
}

# Maps verbosity values (repetitions of -v) to log levels
log_levels = [Logger::ERROR, Logger::INFO, Logger::DEBUG]

def cache_builder(conf)
  json_api = Aspire::API::JSON.new(conf[:api_client_id], conf[:api_secret],
                                   conf[:tenant], **api_opts)
  ld_api = Aspire::API::LinkedData.new(
    conf[:tenant],
    tenancy_host_aliases: conf[:tenancyalias],
    tenancy_root: conf[:tenancyroot],
    **api_opts)
  cache = Aspire::Caching::Cache(json_api, ld_api)
  Aspire::Caching::Builder.new(cache)
end

def config(opts)
  file = opts[:configfile] || '/etc/aspire/build_cache.conf'
  conf = {}
  File.foreach(file) do |line|
    line = line.strip
    next if line.nil? || line.empty? || line[0] == '#'
    key, value = line.split(/\s*=\s*/)
    conf[key.to_sym] = value unless key.empty? || key.nil?
  end
  conf.merge!(opts)
  config_defaults(conf)
end

def config_defaults(conf)
  cache_mode = conf[:cachemode]
  conf[:cachemode] = cache_mode ? cache_mode.to_i(8) : 0o700
  tenancy_alias = conf[:tenancyalias]
  conf[:tenancyalias] = if tenancy_alias.nil? || tenancy_alias.empty?
                          []
                        else
                          tenancy_alias.to_s.split(/\s*;\s*/)
                        end
  conf
end

def list_enumerator(conf)
  filters = [
    proc { |row| time_periods.include?(row['Time Period']) }
  ]
  Aspire::Enumerator::ListReportEnumerator.new(conf[:listfile], filters)
                                          .enumerator
end

def logger(conf)
  logger = Logger.new(conf[:logfile] || STDERR)
  logger.datetime_format = '%Y-%m-%d %H:%M:%S'
  logger.level = log_levels[conf[:verbose].to_i] || Logger::ERROR
  logger.progname = 'build_cache'
  logger.formatter = proc do |severity, datetime, program, msg|
    "#{datetime}: #{program} [#{severity}]: #{msg}\n"
  end
  logger
end

def options
  opts = {}
  OptionParser.new do |opt|
    opt.on('-c', '--configfile FILE', 'The configuration file') do |o|
      opts[:configfile] = o
    end
    opt.on('-d', '--delete', 'Delete the cache before building') do |o|
      opts[:clear] = true
    end
    opt.on('-l', '--listfile FILE', 'The all-lists CSV file') do |o|
      opts[:listfile] = o
    end
    opt.on('-o', '--logfile FILE', 'The log output file') do |o|
      opts[:logfile] = o
    end
    opt.on('-v', '--verbose', 'Increase the logging level') do |o|
      opts[:verbose] = opts[:verbose].to_i + 1
    end
  end.parse!
  options_filters(opts)
end

def options_filters(opts)
  opts[:filters] = {}
  ARGV.each do |arg|
    # If no type qualifier is given, assume a list ID
    type, value = arg.include?(':') ? arg.split(':') : [nil, arg]
    type = 'l' if type.nil? || type.empty?
    type = type.to_sym
    if type == :l
      value = "lists/#{value}"
    elsif type == :u
      value = Date.strptime(value, '%Y-%m-%d')
    end
    if opts[:filters][type]
      opts[:filters][type] << value
    else
      opts[:filters][type] = [value]
    end
  end
  opts
end


# Get the command-line options
opts = options

# Get the configuration
conf = config(opts)

# Get the cache builder
builder = cache_builder(opts)

