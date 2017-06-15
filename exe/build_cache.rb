require 'clamp'

Clamp do

  option %w[-h --hcode], 'HIERARCHY_CODE', 'the hierarchy code (module etc.)'
  option %w[-l --list], 'LIST_URI', 'the list URI'
  option %w[-t --time], 'TIME_PERIOD', 'the time period (2016-17 etc.)'
  option %w[-u --update], 'LAST_UPDATED', 'the last-updated time'
end