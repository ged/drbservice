#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'
require 'openssl'

require 'termios'

SERVICE_URI = "drbssl://localhost:8484"

config = {
	:SSLVerifyMode => OpenSSL::SSL::VERIFY_NONE
}

### Turn echo and masking of input on/off. 
def noecho( masked=false )
	rval = nil
	term = Termios.getattr( $stdin )

	begin
		newt = term.dup
		newt.c_lflag &= ~Termios::ECHO
		newt.c_lflag &= ~Termios::ICANON if masked

		Termios.tcsetattr( $stdin, Termios::TCSANOW, newt )

		rval = yield
	ensure
		Termios.tcsetattr( $stdin, Termios::TCSANOW, term )
	end

	return rval
end


### Prompt the user for her password, turning off echo if the 'termios' module is
### available.
def prompt_for_password( prompt="Password: " )
	rval = nil
	noecho( true ) do
		$stderr.print( prompt )
		rval = ($stdin.gets || '').chomp
	end
	$stderr.puts
	return rval
end


$stderr.puts "Starting the SSL+DRb service..."
DRb.start_service( nil, nil, config )
$stderr.puts "  getting the authenticator object..."
authenticator = DRbObject.new_with_uri( SERVICE_URI )
$stderr.puts "  got it: %p" % [ authenticator ]

pass = prompt_for_password()
$stderr.puts "  authenticating..."
rval = authenticator.authenticate( 'mgranger', pass ) do |service|
	$stderr.puts "Authenticated. Service is: %p" % [ service ]
	if service.homedir_exist?( 'mgranger' )
		$stderr.puts "  homedir exists."
	else
		$stderr.puts "  homedir doesn't exist."
	end
end

$stderr.puts "  authenticator returned: %p" % [ rval ]

