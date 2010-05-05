#!/usr/bin/ruby -*- ruby -*-

BEGIN {
	require 'rbconfig'
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.expand_path
	libdir = basedir + "lib"
	extdir = libdir + Config::CONFIG['sitearch']

	puts ">>> Adding #{libdir} to load path..."
	$LOAD_PATH.unshift( libdir.to_s )
}


# Try to require the 'thingfish' library
begin
	$stderr.puts "Loading DRbService..."
	require 'logger'
	require 'drbservice'

	DRbService.logger.level = Logger::DEBUG if $DEBUG
rescue => e
	$stderr.puts "Ack! DRbService library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end

