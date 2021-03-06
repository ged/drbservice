#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'uri'
require 'yaml'
require 'drbservice'


module DRbService::TestConstants

	VALID_SERVICE_URISTRING = "drbauthssl://localhost:8484"
	VALID_SERVICE_URI = URI( VALID_SERVICE_URISTRING )

end # module DRbService::TestConstants


### RSpec helper functions.
module DRbService::SpecHelpers

	### Make an easily-comparable version vector out of +ver+ and return it.
	def vvec( ver )
		return ver.split('.').collect {|char| char.to_i }.pack('N*')
	end


	class ArrayLogger
		### Create a new ArrayLogger that will append content to +array+.
		def initialize( array )
			@array = array
		end

		### Write the specified +message+ to the array.
		def write( message )
			@array << message
		end

		### No-op -- this is here just so Logger doesn't complain
		def close; end

	end # class ArrayLogger


	unless defined?( LEVEL )
		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		  }
	end

	###############
	module_function
	###############

	### Reset the logging subsystem to its default state.
	def reset_logging
		DRbService.reset_logger
	end


	### Alter the output of the default log formatter to be pretty in SpecMate output
	def setup_logging( level=Logger::FATAL )

		# Turn symbol-style level config into Logger's expected Fixnum level
		if DRbService::Logging::LEVEL.key?( level )
			level = DRbService::Logging::LEVEL[ level ]
		end

		logger = Logger.new( $stderr )
		DRbService.logger = logger
		DRbService.logger.level = level

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			logdevice = ArrayLogger.new( Thread.current['logger-output'] )
			DRbService.logger = Logger.new( logdevice )
			# DRbService.logger.level = level
			DRbService.logger.formatter = DRbService::HtmlLogFormatter.new( logger )
		end
	end

end

### Mock with Rspec
RSpec.configure do |c|
	include DRbService::SpecHelpers,
	        DRbService::TestConstants

	c.mock_with :rspec

	c.filter_run_excluding( :ruby_1_9_only => true ) unless vvec( RUBY_VERSION ) >= vvec('1.9.0')
end

# vim: set nosta noet ts=4 sw=4:

