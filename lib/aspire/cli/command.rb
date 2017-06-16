require 'clamp'

module Aspire
  module CLI

    class Command < Clamp::Command

      # option ['-c', '--hierarchy-code'], 'HIERARCHY_CODE', 'the hierarchy code (module etc.)'
      option ['-e', '--env-file'], 'ENV_FILE', 'file containing env variable key value pairs'
      option ['-l', '--list-uri'], 'LIST_URI', 'the list URI'
      option ['-t', '--time-period'], 'TIME_PERIOD', 'the time period (2016-17 etc.)', :multivalued => true
      option ['-p', '--privacy-control'], 'PRIVACY_CONTROL', 'the list privacy control (Public etc)'
      option ['-s', '--status'], 'STATUS', 'the list status control (Published etc)'
      option ['-c', '--clear-cache'], :flag, 'clear cache before running', default: false
      option ['-f', '--log-to-file'], :flag, 'log output to file', default: false

    end

  end
end