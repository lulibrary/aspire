require 'fileutils'
require 'json'
require 'uri'

require 'aspire/util'

module Aspire
  # Tools for building a caching from the Aspire APIs
  module Caching
    # Cache utility methods
    module Util
      include Aspire::Util

      # Adds a prefix to a filename
      # @param filename [String] the filename
      # @param prefix [String] the prefix
      # @return [String] the filename with prefix
      def add_filename_prefix(filename, prefix)
        filename = filename.rpartition(File.basename(filename))
        filename[1] = "#{prefix}#{filename[1]}"
        filename.join
      end

      # Adds a suffix to a filename
      # @param filename [String] the filename
      # @param suffix [String] the suffix
      # @return [String] the filename with suffix
      def add_filename_suffix(filename, suffix)
        filename = filename.rpartition(File.extname(filename))
        filename[2] = filename[1]
        filename[1] = suffix
        filename.join
      end

      # Returns true if the directory path has no more parents, false otherwise
      # @param dir [String] the directory path
      # @param root [String] the directory root - paths above this are ignored
      # @return [Boolean] true if there are no more parents, false otherwise
      def end_of_path?(dir, root = nil)
        dir.nil? || dir.empty? || dir == '.' || dir == root
      end

      # Creates a directory and its parents, logs errors
      # @param dir [String] the directory name
      # @param logger [Aspire::Caching::CacheLogger] the logger for messages
      # @param failure [String] the error message on failure
      # @return [void]
      # @raise [ArgumentError] if the directory is not specified
      # @raise [Aspire::Cache::Exceptions::WriteError] if the operation fails
      def mkdir(dir, logger = nil, success = nil, failure = nil)
        raise ArgumentError, 'Directory expected' if dir.nil? || dir.empty?
        FileUtils.mkdir_p(dir, mode: mode)
        return if logger.nil? || success.nil? || success.empty?
        logger.log(Logger::DEBUG, success)
      rescue SystemCallError => e
        failure ||= "Create directory #{dir} failed"
        message = "#{failure}: #{e}"
        raise WriteError, message if logger.nil?
        logger.log_exception(message, WriteError)
      end

      # Removes the specified files
      # @param glob [String] the file pattern to be removed
      # @param logger [Aspire::Caching::CacheLogger] the logger for messages
      # @param success [String] the text for success log messages
      # @param failure [String] the text for failure exception/log messages
      # @return [void]
      # @raise [Aspire::Cache::Exceptions::RemoveError] if the removal fails
      def rm(glob, logger = nil, success = nil, failure = nil)
        raise ArgumentError, 'file path required' if glob.nil? || glob.empty?
        FileUtils.rm_rf(Dir.glob(glob), secure: true)
        return if logger.nil? || success.nil? || success.empty?
        logger.log(Logger::INFO, success)
      rescue SystemCallError => e
        failure ||= "Remove #{glob} failed"
        message = "#{failure}: #{e}"
        raise RemoveError, message if logger.nil?
        logger.log_exception("#{failure}: #{e}", RemoveError)
      end

      # Remove empty directories in a directory path
      # @param path [String] the starting file or directory
      # @param root
      # @return [void]
      # @raise [Aspire::Caching::Exceptions::RemoveError] if the operation fails
      def rmdir_empty(path, root)
        # The starting path is assumed to be a filename, so we append a dummy
        # filename if it's a directory
        dir = File.directory?(dir) ? File.join(flags[:file], '.') : dir
        loop do
          # Get the parent of the current directory/file
          dir = File.dirname(dir)
          # Stop at the end of the directory path or a non-empty directory
          break if end_of_path?(dir, root) || !Dir.empty?(dir)
          # Remove the directory
          Dir.rmdir(dir)
        end
      rescue Errno::ENOTEMPTY, Errno::ENOTDIR
        # Stop without error if the directory is not empty or not a directory
        nil
      rescue SystemCallError => e
        raise RemoveError, "Rmdir #{dir} failed: #{e}"
      end

      # Removes the file extension from a path
      # @param path [String] the file path
      # @return [String] the file path with any extension removed
      def strip_ext(path)
        path.rpartition(File.extname(path))[0]
      end
    end
  end
end