#!/usr/bin/env ruby

require 'pathname'
require 'drb'
require 'drb/ssl'
require 'openssl'

require 'treequel'

COMPANY_NAME = 'laika'
SERVICE_URI = "drbssl://localhost:8484"

EXPDIR = Pathname( __FILE__ ).dirname
KEYFILE = EXPDIR + 'key.pem'
CERTFILE = EXPDIR + 'cert.pem'

SSL_CONFIG     = {
	'C'            => 'US',
	'ST'           => 'Oregon',
	'L'            => 'Portland',
	'O'            => "#{COMPANY_NAME.upcase}, Inc.",
	'CN'           => "services.#{COMPANY_NAME}.com",
	'emailAddress' => "it@lists.#{COMPANY_NAME}.com",
}

class Service
	include DRbUndumped

	@@real_methods = {}
	@unguarded_mode = false
	class << self; attr_accessor :unguarded_mode; end

	def self::unguarded
		self.unguarded_mode = true
		yield
	ensure
		self.unguarded_mode = false
	end

	def self::method_added( meth )
		super
		unless self.unguarded_mode || self == ::Service || meth.to_sym == :initialize
			$stderr.puts "Obscuring #{meth}."
			@@real_methods[ self ] ||= {}
			@@real_methods[ self ][ meth.to_sym ] = self.instance_method( meth )
			remove_method( meth )
		end
	end


	def self::real_method( sym )
		return @@real_methods[ self ][ sym ]
	end


	def initialize
		@ldap = Treequel.directory( "ldap://ldap.#{COMPANY_NAME}.com/dc=#{COMPANY_NAME},dc=com" )
		@people = @ldap.ou( :people )
		@authenticated = false
		super
	end

	attr_reader :authenticated

	### Authenticate, and if successful, add the service to the proxied object.
	def authenticate( uid, password )
		person = @people.uid( uid )
		$stderr.puts "Checking authentication for %p" % [ person ]
		@ldap.bound_as( person, password ) do
			$stderr.puts "Authentication succeeded. Setting authenticated flag."
			@authenticated = true
			yield
		end

	rescue => err
		$stderr.puts "%s while authenticating %p: %s" % [ err.class.name, uid, err.message ]
		return nil
	ensure
		@authenticated = false
	end


	#########
	protected
	#########

	def method_missing( sym, *args )
		return super unless body = self.class.real_method( sym )
		raise SecurityError, "not authenticated" unless self.authenticated
		return body.clone.bind( self ).call( *args )
	end

end # class Service


### A simple little example service that checks for the existance of a home directory following 
### the convention of /#{COMPANY_NAME}/home/<first character of username>/<username>.
class HomeDirService < Service

	### Create the service object
	def initialize
		@homedir = Pathname( "/#{COMPANY_NAME}/home" )
		super
	end

	unguarded do

		### Return +true+ if a home directory for the specified +username+ exists.
		def homedir_exist?( username )
			userhome = @homedir + username[0,1] + username
			$stderr.puts "Checking existance of %p" % [ userhome ]
			return userhome.exist?
		end

	end

	def create_homedir( username )
		userhome = @homedir + username[0,1] + username
		$stderr.puts "Creating homedir for %s: %p" % [ username, userhome ]
		return  "%s created (well, not really, but it would have been)" % [ userhome ]
	end

end # class Service


### Generate a key if there isn't already one in the current directory.
cert = key = nil
unless KEYFILE.exist?
	$stderr.print "Generating server cert..."
	key = OpenSSL::PKey::RSA.new( 2048 ){ $stderr.print "." }
	$stderr.puts
	KEYFILE.open( File::WRONLY|File::CREAT|File::EXCL, 0600 ) do |fh|
		fh.print( key.to_pem )
	end
end
key  ||= OpenSSL::PKey::RSA.new( KEYFILE.read )

### Same for the cert -- generate one on demand
unless CERTFILE.exist?
	name = OpenSSL::X509::Name.new( SSL_CONFIG.to_a )

	cert = OpenSSL::X509::Certificate.new
	cert.version    = 2
	cert.serial     = 0
	cert.subject    = name
	cert.issuer     = name
	cert.not_before = Time.now
	cert.not_after  = Time.now + 3600
	cert.public_key = key.public_key

	ef = OpenSSL::X509::ExtensionFactory.new( nil, cert )
	cert.extensions = [
		ef.create_extension( "basicConstraints","CA:FALSE" ),
		ef.create_extension( "subjectKeyIdentifier","hash" ),
		ef.create_extension( "extendedKeyUsage","serverAuth" ),
		ef.create_extension( "keyUsage", "keyEncipherment,dataEncipherment,digitalSignature" ),
	]

	ef.issuer_certificate = cert

	cert.sign( key, OpenSSL::Digest::SHA1.new )
	cert.extensions << ef.create_extension( "authorityKeyIdentifier", "keyid:always,issuer:always" )

	CERTFILE.open( File::WRONLY|File::CREAT|File::EXCL, 0644 ) do |fh|
		fh.print( cert.to_pem )
	end
end
cert ||= OpenSSL::X509::Certificate.new( CERTFILE.read )


config = {
	:SSLPrivateKey => key,
	:SSLCertificate => cert,
}

# Start the example HomeDirService wrapped in DRb+SSL and wait for it to finish.
DRb.start_service( SERVICE_URI, HomeDirService.new, config )
DRb.thread.join


