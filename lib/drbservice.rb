#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'

require 'digest/sha1'


# A base class for DRb-based services.

class DRbService
	require 'drbservice/utils'
	include DRbUndumped,
	        DRbService::Logging

	# Library version
	VERSION = '1.0.0'

	# Version-control revision
	REVISION = %$Rev$



	# The container for obscured methods
	@@real_methods = {}


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Start the DRbService at the given +uri+ and join on its thread.
	def self::start( uri, config={} )
		frontobj = self.new
		$SAFE = 1
		DRbService.log.info "Starting %p as a DRbService at %s with config: %p" % [ self, uri, config ]
		DRb.start_service( uri, frontobj, config )
		DRbService.log.debug "  started. Joining the DRb thread."
		DRb.thread.join
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


	### Set a password for the service. If you don't specify a password, even guarded
	### methods can be accessed. With a password set, the remote side can still call
	### unguarded methods, but all other methods will be hidden.
	def self::service_password( password )
		DRbService.log.debug "Setting encrypted password for %p to "
		self.password_digest = Digest::SHA1.hexdigest( password )
	end


	### Class accessors
	class << self
		# The unguarded mode flag -- instance methods defined while this flag is set
		# will not be hidden
		attr_accessor :unguarded_mode

		# The SHA1 digest of the service password -- if nil, the service will not require
		# authentication
		attr_accessor :password_digest
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
		return (self.class.password_digest.nil? || @authenticated) ? true : false
	end


 	### Authenticate using the specified +password+, calling the provided block if 
	### authentication succeeds. Raises a SecurityError if authentication fails. If
	### no password is set, the block is called regardless of what the +password+ is.
	def authenticate( password )
		if digest = self.class.password_digest
			if Digest::SHA1.hexdigest( password ) == digest
				self.log.info "authentication successful"
				@authenticated = true
				yield
			else
				self.log.error "authentication failure"
				raise SecurityError, "authentication failure"
			end
		else
			self.log.info "ignoring authentication to an unguarded service"
			yield
		end
	ensure
		@authenticated = false
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


