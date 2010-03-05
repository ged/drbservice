#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'
require 'openssl'

require 'password'

URI = "drbssl://localhost:8484"

config = {
	:SSLVerifyMode => OpenSSL::SSL::VERIFY_NONE
}

DRb.start_service( nil, nil, config )
authenticator = DRbObject.new_with_uri( URI )

pass = Password.get( 'Password:' )
authenticator.authenticate( 'mgranger', pass ) do |service|
	puts "Authenticated. Service is: %p" % [ service ]
	if service.homedir_exist?( 'mgranger' )
		puts "  homedir exists."
	else
		puts "  homedir doesn't exist."
	end
end


