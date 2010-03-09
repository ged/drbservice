#!/usr/bin/ruby

require 'logger'
require 'erb'
require 'bigdecimal'
require 'date'

require 'drbservice'


class DRbService # :nodoc:

	### A collection of ANSI color utility functions
	module ANSIColorUtilities

		# Set some ANSI escape code constants (Shamelessly stolen from Perl's
		# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
		ANSI_ATTRIBUTES = {
			'clear'      => 0,
			'reset'      => 0,
			'bold'       => 1,
			'dark'       => 2,
			'underline'  => 4,
			'underscore' => 4,
			'blink'      => 5,
			'reverse'    => 7,
			'concealed'  => 8,

			'black'      => 30,   'on_black'   => 40,
			'red'        => 31,   'on_red'     => 41,
			'green'      => 32,   'on_green'   => 42,
			'yellow'     => 33,   'on_yellow'  => 43,
			'blue'       => 34,   'on_blue'    => 44,
			'magenta'    => 35,   'on_magenta' => 45,
			'cyan'       => 36,   'on_cyan'    => 46,
			'white'      => 37,   'on_white'   => 47
		}

		###############
		module_function
		###############

		### Create a string that contains the ANSI codes specified and return it
		def ansi_code( *attributes )
			attributes.flatten!
			attributes.collect! {|at| at.to_s }
			return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
			attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

			if attributes.empty? 
				return ''
			else
				return "\e[%sm" % attributes
			end
		end


		### Colorize the given +string+ with the specified +attributes+ and return it, handling 
		### line-endings, color reset, etc.
		def colorize( *args )
			string = ''

			if block_given?
				string = yield
			else
				string = args.shift
			end

			ending = string[/(\s)$/] || ''
			string = string.rstrip

			return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
		end

	end # module ANSIColorUtilities


	# 
	# A alternate formatter for Logger instances.
	# 
	# == Usage
	# 
	#   require 'drbservice/utils'
	#   DRbService.logger.formatter = DRbService::LogFormatter.new( DRbService.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class LogFormatter < Logger::Formatter

		# The format to output unless debugging is turned on
		DEFAULT_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"

		# The format to output if debugging is turned on
		DEFAULT_DEBUG_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s {%6$s} -- %7$s\n"


		### Initialize the formatter with a reference to the logger so it can check for log level.
		def initialize( logger, format=DEFAULT_FORMAT, debug=DEFAULT_DEBUG_FORMAT ) # :notnew:
			@logger       = logger
			@format       = format
			@debug_format = debug

			super()
		end

		######
		public
		######

		# The Logger object associated with the formatter
		attr_accessor :logger

		# The logging format string
		attr_accessor :format

		# The logging format string that's used when outputting in debug mode
		attr_accessor :debug_format


		### Log using either the DEBUG_FORMAT if the associated logger is at ::DEBUG level or
		### using FORMAT if it's anything less verbose.
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity,                                                     # %5$s
				progname,                                                     # %6$s
				msg                                                           # %7$s
			]

			if @logger.level == Logger::DEBUG
				return self.debug_format % args
			else
				return self.format % args
			end
		end
	end # class LogFormatter


	# 
	# A ANSI-colorized formatter for Logger instances.
	# 
	# == Usage
	# 
	#   require 'drbservice/utils'
	#   DRbService.logger.formatter = DRbService::ColorLogFormatter.new( DRbService.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class ColorLogFormatter < Logger::Formatter
		extend DRbService::ANSIColorUtilities

		# Color settings
		LEVEL_FORMATS = {
			:debug => colorize( :bold, :black ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s {%6$s} -- %7$s\n"},
			:info  => colorize( :normal ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:warn  => colorize( :bold, :yellow ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:error => colorize( :red ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
			:fatal => colorize( :bold, :red, :on_white ) {"[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"},
		}


		### Initialize the formatter with a reference to the logger so it can check for log level.
		def initialize( logger, settings={} ) # :notnew:
			settings = LEVEL_FORMATS.merge( settings )

			@logger   = logger
			@settings = settings

			super()
		end

		######
		public
		######

		# The Logger object associated with the formatter
		attr_accessor :logger

		# The formats, by level
		attr_accessor :settings


		### Log using the format associated with the severity
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity,                                                     # %5$s
				progname,                                                     # %6$s
				msg                                                           # %7$s
			]

			return self.settings[ severity.downcase.to_sym ] % args
		end
	end # class LogFormatter


	# 
	# An alternate formatter for Logger instances that outputs +div+ HTML
	# fragments.
	# 
	# == Usage
	# 
	#   require 'drbservice/utils'
	#   DRbService.logger.formatter = DRbService::HtmlLogFormatter.new( DRbService.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class HtmlLogFormatter < Logger::Formatter
		include ERB::Util  # for html_escape()

		# The default HTML fragment that'll be used as the template for each log message.
		HTML_LOG_FORMAT = %q{
		<div class="log-message %5$s">
			<span class="log-time">%1$s.%2$06d</span>
			[
				<span class="log-pid">%3$d</span>
				/
				<span class="log-tid">%4$s</span>
			]
			<span class="log-level">%5$s</span>
			:
			<span class="log-name">%6$s</span>
			<span class="log-message-text">%7$s</span>
		</div>
		}

		### Override the logging formats with ones that generate HTML fragments
		def initialize( logger, format=HTML_LOG_FORMAT ) # :notnew:
			@logger = logger
			@format = format
			super()
		end


		######
		public
		######

		# The HTML fragment that will be used as a format() string for the log
		attr_accessor :format


		### Return a log message composed out of the arguments formatted using the
		### formatter's format string
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity.downcase,                                                     # %5$s
				progname,                                                     # %6$s
				html_escape( msg ).gsub(/\n/, '<br />')                       # %7$s
			]

			return self.format % args
		end

	end # class HtmlLogFormatter


	### DRbService logging methods and data.
	module Logging

		# Mapping of symbols to logging levels
		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		  }


		def self::included( mod )

			# Logging class instance variables
			default_logger = Logger.new( $stderr )
			default_logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN
			formatter = DRbService::LogFormatter.new( default_logger )
			default_logger.formatter = formatter

			mod.instance_variable_set( :@default_logger, default_logger )
			mod.instance_variable_set( :@default_log_formatter, formatter ) 
			mod.instance_variable_set( :@logger, default_logger )

			# Accessors
			class << mod
				include DRbService::Logging::ClassMethods

				# The log formatter that will be used when the logging subsystem is reset
				attr_accessor :default_log_formatter

				# The logger that will be used when the logging subsystem is reset
				attr_accessor :default_logger

				# The logger that's currently in effect
				attr_accessor :logger
				alias_method :log, :logger
				alias_method :log=, :logger=
			end

		end


		### A collection of class methods that will get added as class method to anything that 
		### includes Logging.
		module ClassMethods

			### Reset the global logger object to the default
			def reset_logger
				self.logger = self.default_logger
				self.logger.level = Logger::WARN
				self.logger.formatter = self.default_log_formatter
			end


			### Returns +true+ if the global logger has not been set to something other than
			### the default one.
			def using_default_logger?
				return self.logger == self.default_logger
			end


			### Return the library's version string
			def version_string( include_buildnum=false )
				vstring = "%s %s" % [ self.name, self.const_get(:VERSION) ]
				if include_buildnum
					rev = self.const_get(:REVISION)[/: ([[:xdigit:]]+)/, 1] rescue '0'
					vstring << " (build %s)" % [ rev ]
				end
				return vstring
			end

		end # module ClassMethods


		### A logging proxy class that wraps calls to the logger into calls that include
		### the name of the calling class.
		class ClassNameProxy # :nodoc:

			### Create a new proxy for the given +klass+.
			def initialize( klass, force_debug=false )
				@classname   = klass.name
				@force_debug = force_debug
			end

			### Delegate calls the global logger with the class name as the 'progname' 
			### argument.
			def method_missing( sym, msg=nil, &block )
				return super unless LEVEL.key?( sym )
				sym = :debug if @force_debug
				DRbService.logger.add( LEVEL[sym], msg, @classname, &block )
			end
		end # ClassNameProxy


		### Copy constructor -- clear the original's log proxy.
		def initialize_copy( original )
			@log_proxy = @log_debug_proxy = nil
			super
		end


		### Return the proxied logger.
		def log
			@log_proxy ||= ClassNameProxy.new( self.class )
		end


		### Return a proxied "debug" logger that ignores other level specification.
		def log_debug
			@log_debug_proxy ||= ClassNameProxy.new( self.class, true )
		end

	end # module Logging


end # class DRbService

# vim: set nosta noet ts=4 sw=4:

