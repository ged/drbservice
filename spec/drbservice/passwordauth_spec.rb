#!/usr/bin/spec

BEGIN {
	require 'pathname'

	basedir = Pathname( __FILE__ ).dirname.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'digest/sha2'

require 'rspec'

require 'spec/lib/helpers'

require 'drbservice'
require 'drbservice/passwordauth'


describe DRbService::PasswordAuthentication do
	include DRbService::SpecHelpers

	TEST_PASSWORD = 'hungerlumpkins'

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	describe "mixed into a DRbService" do

		it "provides a declarative to set a password for the service" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::PasswordAuthentication
				def do_some_stuff; return "Yep."; end
				service_password TEST_PASSWORD
			end
			serviceclass.password_digest.should == Digest::SHA2.hexdigest( TEST_PASSWORD )
		end

		describe "without a password set" do

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


			it "raises an exception without calling the block on any authentication" do
				block_called = false
				expect {
					@serviceobj.authenticate( '' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication failure/i )
				block_called.should == false
			end

			it "doesn't allow access to guarded methods" do
				expect {
					@serviceobj.do_some_guarded_stuff
				}.to raise_exception( SecurityError, /not authenticated/i )
			end

			it "allows access to unguarded methods" do
				@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
			end

		end


		describe "instances with a password set" do

			before( :each ) do
				@serviceclass = Class.new( DRbService ) do
					include DRbService::PasswordAuthentication
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

