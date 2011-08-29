#!/usr/bin/env ruby

require 'uri'

require 'drb'
require 'drb/ssl'

module DRb

	# A DRb protocol implementation that provides an authenticated, encrypted channel
	# for DRb services.
	class DRbAuthenticatedSSLSocket < DRbSSLSocket

		# The scheme of URIs which specify this protocol
		SCHEME = 'drbauthssl'


		### Parse a drbauthssl:// URI. Accepts a String, a URI, or any object that responds to 
		### #host, #port, and #query.
		### Return the values from the URI as an Array of the form: [ host, port, optionhash ].
		### Raises DRbBadScheme if the +uri+ is not a +drbauthssl+ URI.
		### Raises DRbBadURI if the +uri+ is missing the port number.
		def self::parse_uri( uri )
			uri = URI( uri ) unless uri.respond_to?( :host )
			raise DRbBadScheme, "not a #{SCHEME} URI: %p" % [ uri ] unless 
				uri.scheme == SCHEME
			raise DRbBadURI, "missing the port number" unless
				uri.port && uri.port.to_i.nonzero?

			return [ uri.host, uri.port.to_i, uri.query ]
		end


		### Open a client connection to the server at +uri+, using configuration 
		### +config+.  Return a protocol instance for this connection.
		def self::open( uri, config )
			host, port, option = self.parse_uri( uri )
			host.untaint
			port.untaint
			soc = TCPSocket.open( host, port )
			ssl_conf = DRb::DRbSSLSocket::SSLConfig.new( config )
			ssl_conf.setup_ssl_context
			ssl = ssl_conf.connect( soc )
			self.new( uri, ssl, ssl_conf, true )
		end


	end # class DRbAuthenticatedSSLSocket


	DRbProtocol.add_protocol( DRbAuthenticatedSSLSocket )

end # module DRb


