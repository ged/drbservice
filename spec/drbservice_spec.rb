#!/usr/bin/spec

BEGIN {
	require 'pathname'

	basedir = Pathname( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'spec'
require 'spec/lib/helpers'

require 'drbservice'


describe DRbService do
	include DRbService::SpecHelpers

	SERVICE_URI = "drbssl://localhost:8484"


	before( :all ) do
		setup_logging( :debug )
	end


	it "is always an 'undumped' service object" do
		testclass = Class.new( DRbService )
		testclass.should include( DRbUndumped )
	end

	it "obscures instance methods declared by subclasses by default" do
		testclass = Class.new( DRbService ) do
			def do_some_stuff; return "Yep."; end
		end
		testclass.new.should_not respond_to( :do_some_stuff )
	end


	it "provides an 'unguarded' declarative to define instance methods that can " +
	   "be used without authentication" do
		testclass = Class.new( DRbService ) do
			unguarded do
				def do_some_stuff; return "Yep."; end
			end
		end
		testclass.new.should respond_to( :do_some_stuff )
	end


	it "provides a .start class method that does the necessary DRb setup and runs the service" do
		serviceclass = Class.new( DRbService )
		thread = mock( "drb service thread" )

 		DRb.should_receive( :start_service ).with( SERVICE_URI, an_instance_of(serviceclass), {} )
		DRb.should_receive( :thread ).and_return( thread )
		thread.should_receive( :join )

		serviceclass.start( SERVICE_URI )
	end


	it "accepts a configuration hash as an argument to .start" do
		
	end


	it "provides a declarative to set a password for the service"

end