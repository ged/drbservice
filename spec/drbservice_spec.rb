#!/usr/bin/spec

BEGIN {
	require 'pathname'

	basedir = Pathname( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'spec'
require 'spec/lib/helpers'

require 'uri'
require 'drbservice'


describe DRbService do
	include DRbService::SpecHelpers

	SERVICE_URI = URI( "drbssl://localhost:8484" )

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	it "is always an 'undumped' service object" do
		testclass = Class.new( DRbService )
		testclass.should include( DRbUndumped )
	end

	it "doesn't allow instances to be created of itself" do
		expect {
			DRbService.new
		}.should raise_exception( ScriptError, /can't instantiate/ )
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


	describe "subclass" do

		it "is an 'undumped' service objects" do
			serviceclass = Class.new( DRbService )
			serviceclass.should include( DRbUndumped )
		end

		it "obscures instance methods by default" do
			serviceclass = Class.new( DRbService ) do
				def do_some_stuff; return "Yep."; end
			end
			serviceclass.new.should_not respond_to( :do_some_stuff )
		end


		it "can use an 'unguarded' declarative to define instance methods that can " +
		   "be used without authentication" do
			serviceclass = Class.new( DRbService ) do
				unguarded do
					def do_some_stuff; return "Yep."; end
				end
			end
			serviceclass.new.should respond_to( :do_some_stuff )
		end


		it "has a .start class method that does the necessary DRb setup and runs the service" do
			serviceclass = Class.new( DRbService )
			drbserver = mock( "drb server" )
			thread = mock( "drb service thread" )

			expected_config = {
				:SSLCertificate => "service-cert.pem",
				:SSLPrivateKey  => "service-key.pem",
				:safe_level     => 1,
				:verbose        => true,
			}

	 		DRb::DRbServer.should_receive( :new ).
				with( SERVICE_URI.to_s, an_instance_of(serviceclass), expected_config ).
				and_return( drbserver )
			drbserver.should_receive( :thread ).and_return( thread )
			thread.should_receive( :join )

			serviceclass.start( SERVICE_URI.host, SERVICE_URI.port )
		end


		describe "instances without an authentication strategy mixed in" do

			before( :all ) do
				@serviceclass = Class.new( DRbService ) do
					def do_some_guarded_stuff; return "Ronk."; end
					unguarded do
						def do_some_unguarded_stuff; return "Adonk."; end
					end
				end
			end

			before( :each ) do
				@serviceobj = @serviceclass.new
			end


			it "raises an exception when #authenticate is called" do
				expect {
					@serviceobj.authenticate( '' )
				}.to raise_exception( SecurityError, /authentication failure/i )
			end

			it "allows access to unguarded methods without authenticating" do
				@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
			end

		end

	end
end