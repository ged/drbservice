#!/usr/bin/spec

BEGIN {
	require 'pathname'

	basedir = Pathname( __FILE__ ).dirname.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
require 'drb/authsslprotocol'


describe DRb::DRbAuthenticatedSSLSocket do

	before( :all ) do
		setup_logging( :fatal )
	end

	describe "URI parsing method" do
		it "parses a valid drb authenticated SSL URI string into an Array of [host, port, option]" do
			DRb::DRbAuthenticatedSSLSocket.parse_uri( VALID_SERVICE_URISTRING ).should ==
				[ VALID_SERVICE_URI.host, VALID_SERVICE_URI.port, VALID_SERVICE_URI.query ]
		end

		it "parses a valid drb authenticated SSL URI object into an Array of [host, port, option]" do
			DRb::DRbAuthenticatedSSLSocket.parse_uri( VALID_SERVICE_URI ).should ==
				[ VALID_SERVICE_URI.host, VALID_SERVICE_URI.port, VALID_SERVICE_URI.query ]
		end

		it "parses the 'query' part of the URI as the 'option' return value" do
			DRb::DRbAuthenticatedSSLSocket.parse_uri( VALID_SERVICE_URISTRING + '?an_option' ).
				should == [ VALID_SERVICE_URI.host, VALID_SERVICE_URI.port, 'an_option' ]
		end

		it "raises an exception if the URI scheme to be parsed isn't supported by this protocol" do
			expect {
				DRb::DRbAuthenticatedSSLSocket.parse_uri( 'drb://localhost:1718' )
			}.to raise_exception( DRb::DRbBadScheme, /not a drbauthssl/i )
		end

		it "raises an exception if the port isn't specified by the URI to be parsed" do
			expect {
				DRb::DRbAuthenticatedSSLSocket.parse_uri( 'drbauthssl://localhost' )
			}.to raise_exception( DRb::DRbBadURI, /missing the port/i )
		end

	end


	#   [open(uri, config)] Open a client connection to the server at +uri+,
	#                       using configuration +config+.  Return a protocol
	#                       instance for this connection.
	describe "client-open method" do
	end


	#   [open_server(uri, config)] Open a server listening at +uri+,
	#                              using configuration +config+.  Return a
	#                              protocol instance for this listener.
	describe "server-open method" do
	end


	#   [uri_option(uri, config)] Take a URI, possibly containing an option
	#                             component (e.g. a trailing '?param=val'), 
	#                             and return a [uri, option] tuple.
	describe "client-open method" do
	end


end