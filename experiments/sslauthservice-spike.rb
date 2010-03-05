#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'
require 'openssl'

require 'treequel'


URI = "drbssl://localhost:8484"

EXPDIR = Pathname( __FILE__ ).dirname
KEYFILE = EXPDIR + 'key.pem'
CERTFILE = EXPDIR + 'cert.pem'

SSL_CONFIG     = {
	:C            => 'US',
	:ST           => 'Oregon',
	:L            => 'Portland',
	:O            => 'ACME, Inc.',
	:CN           => 'services.acme.com',
	:emailAddress => 'it@acme.com',
}

class Service

	### Create the service object
	def initialize
		@homedir = Pathname( '/laika/home' )
	end

	### Return +true+ if a home directory for the specified +username+ exists.
	def homedir_exist?( username )
		userhome = @homedir + username[0,1] + username
		return username.exist?
	end

end # class Service


class AuthWrapperObject
	include DRbUndumped

	def initialize
		raise "Can't instantiate AuthWrapperObject directly: please subclass it" if
			self.instance_of?( AuthWrapperObject )
		@ldap = Treequel.directory( 'ldap://ldap.laika.com/dc=laika,dc=com' )
		@people = @ldap.ou( :people )
		@serviceobject = nil
		super
	end


	### Authenticate, and if successful, add the service to the proxied object.
	def authenticate( uid, password )
		person = @people.uid( uid )
		begin
			@ldap.bind_as( person, password ) do
				yield Service.new
			end
		rescue => err
			$stderr.puts "%s while authenticating %p: %s" % [ err.class.name, uid, err.message ]
			return nil
		end
	end

end # class AuthWrapperObject


cert = key = nil

unless CERTFILE.exist? && KEYFILE.exist?
	$stderr.print "Generating server cert..."
	key = OpenSSL::PKey::RSA.new( 2048 ){ $stderr.print "." }
	$stderr.puts
	KEYFILE.open( File::WRONLY|File::CREAT|File::EXCL, 0600 ) do |fh|
		fh.print( key.to_pem )
	end

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
		ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always")
	]

	ef.issuer_certificate = cert

	cert.sign( key, OpenSSL::Digest::SHA1.new )
	CERTFILE.open( File::WRONLY|File::CREAT|File::EXCL, 0644 ) do |fh|
		fh.print( cert.to_pem )
	end
end

cert ||= OpenSSL::X509::Certificate.new( CERTFILE.read )
key  ||= OpenSSL::PKey::RSA.new( KEYFILE.read )


config = {
	:SSLPrivateKey => key,
	:SSLCertificate => cert,
}

DRb.start_service( URI, AuthWrapperObject.new, config )
DRb.thread.join


