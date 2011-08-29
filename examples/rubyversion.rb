#!/usr/bin/env ruby

require 'drbservice'
require 'drbservice/passwordauth'

# An example service that just returns the version of Ruby running on the
# current machine.
class RubyVersionService < DRbService
	include DRbService::PasswordAuthentication

	service_password '6d4bf8ac6490219f4f8807dad066d742f39a2d25501ae66d650cb647cd758979'

	### Fetch the version of Ruby running this service as a vector of
	### three network-byte-order shorts.
	def ruby_version
		return RUBY_VERSION.split( /\./, 3 ).map( &:to_i ).pack( 'n*' )
	end

end

RubyVersionService.start( 
	:ip       => '127.0.0.1',
	:port     => 4848, 
	:certfile => 'service.pem',
	:keyfile  => 'service.pem' )

