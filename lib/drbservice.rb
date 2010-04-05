#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'


# A base class for DRb-based services.

class DRbService
	require 'drbservice/utils'
	include DRbUndumped,
	        DRbService::Logging

	# Library version
	VERSION = '1.0.0'

	# Version-control revision
	REVISION = %$Rev$

	# The default path to the service cert, relative to the current directory
	DEFAULT_CERTNAME = 'service-cert.pem'

	# The default path to the service key, relative to the current directory
	DEFAULT_KEYNAME = 'service-key.pem'


	# The container for obscured methods
	@@real_methods = {}


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Start the DRbService at the given +ip+ and +port+.
	def self::start( ip, port, sslcert=DEFAULT_CERTNAME, sslkey=DEFAULT_KEYNAME )
		frontobj = self.new
		uri = "drbssl://#{ip}:#{port}"
		config = {
			:safe_level     => 1,
			:verbose        => true,
	        :SSLCertificate => sslcert,
	        :SSLPrivateKey  => sslkey,
		}

		DRbService.log.info "Starting %p as a DRbService at %s" % [ self, uri ]
		server = DRb::DRbServer.new( uri, frontobj, config )
		DRbService.log.debug "  started. Joining the DRb thread."
		server.thread.join
	end


	### Obscure any instance method added while not in 'unguarded' mode.
	def self::method_added( meth )
		super
		unless self == ::DRbService || meth.to_sym == :initialize
			if self.unguarded_mode
				DRbService.log.debug "Not obscuring %p#%s: unguarded mode." % [ self, meth ]
			else
				DRbService.log.debug "Obscuring %p#%s." % [ self, meth ]
				@@real_methods[ self ] ||= {}
				@@real_methods[ self ][ meth.to_sym ] = self.instance_method( meth )
				remove_method( meth )
			end
		end
	end


	### Add a per-class 'unguarded mode' flag to subclasses.
	def self::inherited( subclass )
		super
		subclass.instance_variable_set( :@unguarded_mode, false )
	end


	### Declare some service methods that can be called without authentication in
	### the provided block.
	def self::unguarded
		self.unguarded_mode = true
		yield
	ensure
		self.unguarded_mode = false
	end


	### Class accessors
	class << self

		# The unguarded mode flag -- instance methods defined while this flag is set
		# will not be hidden
		attr_accessor :unguarded_mode

	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new instance of the service.
	def initialize
		raise ScriptError,
			"can't instantiate #{self.class} directly: please subclass it instead" if
			self.class == DRbService
		@authenticated = false

		super
	end


	######
	public
	######

	### Returns +true+ if the client has successfully authenticated.
	def authenticated?
		return @authenticated ? true : false
	end


	### Default authentication implementation -- always fails. You'll need to include
	### one of the authentication modules or provide your own #authenticate method in
	### your subclass.
	def authenticate( *args )
		self.log.error "authentication failure (fallback method)"
		raise SecurityError, "authentication failure"
	end


	#########
	protected
	#########

	### Handle calls to guarded methods by requiring the authentication flag be
	### set if there is a password set.
	def method_missing( sym, *args )
		return super unless body = @@real_methods[ self.class ][ sym ]
		if self.authenticated?
			return body.clone.bind( self ).call( *args )
		else
			self.log.error "Guarded method %p called without authentication!" % [ sym ]
			raise SecurityError, "not authenticated"
		end
	end


end # class DRbService


