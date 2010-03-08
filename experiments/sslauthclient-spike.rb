#!/usr/bin/env ruby

require 'etc'

require 'drb'
require 'drb/ssl'
require 'openssl'

require 'termios'

SERVICE_URI = "drbssl://localhost:8484"

# Don't bother verifying the server's cert -- likely will want to
# change this to something stricter for real services.
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


# Use the name of the current user or the 'USER' environment variable
username = Etc.getpwuid( Process.euid ).name || ENV['USER']
pass = prompt_for_password()
newuser = ARGV.first || username

# Connect to the service
$stderr.puts "Starting the SSL+DRb service..."
DRb.start_service( nil, nil, config )
$stderr.puts "  getting the authenticated service object..."
service = DRbObject.new_with_uri( SERVICE_URI )
$stderr.puts "  got it: %p" % [ service ]

# Try to call the obscured method before authenticating
$stderr.puts "  calling the unguarded method before authenticating..."
if service.homedir_exist?( newuser )
	$stderr.puts "  homedir exists."
else
	$stderr.puts "  homedir doesn't exist."
end


$stderr.puts "  calling the guarded method before authenticating..."
begin
	service.create_homedir( newuser )
rescue SecurityError => err
	$stderr.puts "  yep, raised a %s: %s" % [ err.class.name, err.message ]
end

# Authenticate and call the obscured method if successfullyul.
$stderr.puts "  authenticating..."
service.authenticate( username, pass ) do
	$stderr.puts "Authenticated successfully."
	msg = service.create_homedir( newuser )
	$stderr.puts( msg )
end

