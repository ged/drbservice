#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'


# A base class for DRb-based services.
# @abstract Concrete subclasses must provide define the service API by declaring 
#   public methods. Methods declared outside of a .unguarded block will be obscured
#   before the client authenticates.
class DRbService
	require 'drbservice/utils'
	include DRbUndumped,
	        DRbService::Logging

	# Library version
	VERSION = '1.0.1'

	# Version-control revision
	REVISION = %$Rev$

	# The default IP address to listen on
	DEFAULT_IP = '127.0.0.1'

	# The default port to listen on
	DEFAULT_PORT = 4848

	# The default path to the service cert, relative to the current directory
	DEFAULT_CERTNAME = 'service-cert.pem'

	# The default path to the service key, relative to the current directory
	DEFAULT_KEYNAME = 'service-key.pem'

	# The default values for the drbservice config hash
	DEFAULT_CONFIG = {
		:ip       => DEFAULT_IP,
		:port     => DEFAULT_PORT,
		:certfile => DEFAULT_CERTNAME,
		:keyfile  => DEFAULT_KEYNAME,
	}

	# The container for obscured methods
	class << self
		attr_reader :real_methods
	end


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Start the DRbService at the given +ip+ and +port+.
	### @param [Hash] config     the service configuration hash
	### @option config [String]  :ip       the ip to bind to
	### @option config [Fixnum]  :port     the port to listen on
	### @option config [String]  :certfile the name of the server's SSL certificate file
	### @option config [String]  :keyfile  the name of the server's SSL key file
	### @return [void]
	def self::start( config={} )
		config = DEFAULT_CONFIG.merge( config )

		frontobj = self.new( config )
		uri = "drbssl://%s:%d" % config.values_at( :ip, :port )

		cert = OpenSSL::X509::Certificate.new( File.read(config[:certfile]) )
		key  = OpenSSL::PKey::RSA.new( File.read(config[:keyfile]) )

		config = {
			:safe_level     => 1,
			:verbose        => true,
	        :SSLCertificate => cert,
	        :SSLPrivateKey  => key,
		}

		DRbService.log.info "Starting %p as a DRbService at %s" % [ self, uri ]
		server = DRb::DRbServer.new( uri, frontobj, config )
		DRbService.log.debug "  started. Joining the DRb thread."
		server.thread.join
	end


	### Obscure any instance method added while not in 'unguarded' mode.
	### @param [Symbol] meth  the name of the method being added
	### @return [void]
	def self::method_added( meth )
		super
		unless self == ::DRbService || meth.to_sym == :initialize
			if self.unguarded_mode
				DRbService.log.debug "Not obscuring %p#%s: unguarded mode." % [ self, meth ]
			else
				DRbService.log.debug "Obscuring %p#%s." % [ self, meth ]
				@real_methods ||= {}
				@real_methods[ meth.to_sym ] = self.instance_method( meth )
				remove_method( meth )
			end
		end
	end


	### Inheritance callback: Add a per-class 'unguarded mode' flag to subclasses.
	### @param [Class] subclass  the inheriting subclass
	### @return [void]
	def self::inherited( subclass )
		self.log.debug "Setting @unguarded_mode in %p" % [ subclass ]
		subclass.instance_variable_set( :@unguarded_mode, false )
		super
	end


	### Declare some service methods that can be called without authentication in
	### the provided block.
	### @return [void]
	def self::unguarded
		self.unguarded_mode = true
		yield
	ensure
		self.unguarded_mode = false
	end


	### Return the library's version string
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/.*: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	### Class accessors
	class << self

		# The unguarded mode flag -- instance methods defined while this flag is set
		# will not be hidden
		# @return [Boolean] 
		attr_accessor :unguarded_mode

	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new instance of the service.
	### @raise [ScriptError] if DRbService is instantiated directory
	def initialize( config={} )
		raise ScriptError,
			"can't instantiate #{self.class} directly: please subclass it instead" if
			self.class == DRbService
		@authenticated = false
	end


	######
	public
	######

	### Return a human-readable representation of the object.
	def inspect
		return "#<%s:0x%0x>" % [ self.class, self.__id__ * 2 ]
	end


	### Returns +true+ if the client has successfully authenticated.
	def authenticated?
		return @authenticated ? true : false
	end


	### Returns +true+ if the client has successfully authenticated and is authorized 
	### to use the service. By default, authentication is sufficient for authorization;
	### to specify otherwise, override this method in your service's subclass or 
	### include an auth mixin that provides one.
	def authorized?
		return self.authenticated?
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
		return super unless body = self.class.real_methods[ sym ]
		if self.authorized?
			return body.clone.bind( self ).call( *args )
		else
			self.log.error "Guarded method %p called without authentication!" % [ sym ]
			raise SecurityError, "not authenticated"
		end
	end


end # class DRbService


