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

	TEST_PASSWORD = 'hungerlumpkins'


	before( :all ) do
		setup_logging( :fatal )
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


	it "provides a .start class method that does the necessary DRb setup and runs the service" do
		serviceclass = Class.new( DRbService )
		thread = mock( "drb service thread" )

 		DRb.should_receive( :start_service ).with( SERVICE_URI, an_instance_of(serviceclass), {} )
		DRb.should_receive( :thread ).and_return( thread )
		thread.should_receive( :join )

		serviceclass.start( SERVICE_URI )
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
			thread = mock( "drb service thread" )

	 		DRb.should_receive( :start_service ).with( SERVICE_URI, an_instance_of(serviceclass), {} )
			DRb.should_receive( :thread ).and_return( thread )
			thread.should_receive( :join )

			serviceclass.start( SERVICE_URI )
		end


		it "can use a declarative to set a password for the service" do
			serviceclass = Class.new( DRbService ) do
				def do_some_stuff; return "Yep."; end
				service_password TEST_PASSWORD
			end
			serviceclass.password_digest.should == Digest::SHA1.hexdigest( TEST_PASSWORD )
		end


		describe "instances without a password set" do

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


			it "accepts anything for authentication without raising an exception" do
				block_called = false
				@serviceobj.authenticate( '' ) do
					block_called = true
				end
				block_called.should == true
			end

			it "allows access to guarded methods before authenticating" do
				@serviceobj.do_some_guarded_stuff.should == 'Ronk.'
			end

			it "allows access to guarded methods after authenticating" do
				@serviceobj.authenticate( 'anything' ) do
					@serviceobj.do_some_guarded_stuff.should == 'Ronk.'
				end
			end

			it "allows access to unguarded methods before authenticating" do
				@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
			end

			it "allows access to unguarded methods after authenticating" do
				@serviceobj.authenticate( 'anything' ) do
					@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
				end
			end

		end


		describe "instances with a password set" do

			before( :each ) do
				@serviceclass = Class.new( DRbService ) do
					service_password TEST_PASSWORD
					def do_some_guarded_stuff; return "Ronk."; end
					unguarded do
						def do_some_unguarded_stuff; return "Adonk."; end
					end
				end
			end

			before( :each ) do
				@serviceobj = @serviceclass.new
			end


			it "raises an exception without calling the block on failed authentication" do
				block_called = false
				expect {
					@serviceobj.authenticate( '' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication failure/i )
				block_called.should == false
			end

			it "doesn't allow access to guarded methods before authenticating" do
				expect {
					@serviceobj.do_some_guarded_stuff
				}.to raise_exception( SecurityError, /not authenticated/i )
			end

			it "allows access to guarded methods after authenticating successfully" do
				@serviceobj.authenticate( TEST_PASSWORD ) do
					@serviceobj.do_some_guarded_stuff.should == 'Ronk.'
				end
			end

			it "allows access to unguarded methods before authenticating" do
				@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
			end

			it "allows access to unguarded methods after authenticating" do
				@serviceobj.authenticate( TEST_PASSWORD ) do
					@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
				end
			end

		end

	end
end