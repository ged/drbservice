#!/usr/bin/spec

BEGIN {
	require 'pathname'

	basedir = Pathname( __FILE__ ).dirname.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'treequel'

require 'rspec'
require 'spec/lib/helpers'

require 'drbservice'
require 'drbservice/ldapauth'


describe DRbService::LDAPAuthentication do
	include DRbService::SpecHelpers

	TEST_URI = 'ldap://ldap.acme.com/dc=acme,dc=com'
	TEST_DN_PATTERN = 'uid=%s,ou=people,dc=acme,dc=com'
	TEST_FILTER_PATTERN = '(&(uid=%s)(objectClass=posixAccount))'
	TEST_BASE = 'ou=employees,dc=acme,dc=com'


	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	describe "mixed into a DRbService" do

		it "provides a declarative to set the LDAP URI for the service" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_uri TEST_URI
			end
			serviceclass.ldap_uri.should == TEST_URI
		end

		it "provides a declarative to set a string pattern for the DN of the binding user" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_dn TEST_DN_PATTERN
			end
			serviceclass.ldap_dn.should == TEST_DN_PATTERN
		end

		it "provides a declarative to set a search filter for finding the DN of the binding user" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_dn_search TEST_FILTER_PATTERN
			end
			serviceclass.ldap_dn_search.should == {
				:scope  => :sub,
				:filter => TEST_FILTER_PATTERN,
				:base   => nil,
			}
		end

		it "accepts an optional search base dn as an argument to the search filter declarative" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_dn_search TEST_FILTER_PATTERN, :base => TEST_BASE
			end
			serviceclass.ldap_dn_search.should == {
				:filter => TEST_FILTER_PATTERN,
				:base   => TEST_BASE,
				:scope  => :sub,
			}
		end

		it "accepts an optional scope as an argument to the search filter declarative" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_dn_search TEST_FILTER_PATTERN, :scope => :one
			end
			serviceclass.ldap_dn_search.should == {
				:filter => TEST_FILTER_PATTERN,
			 	:scope  => :one,
				:base   => nil,
			}
		end

		it "accepts both a scope and a base as arguments to the search filter declarative" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_dn_search TEST_FILTER_PATTERN, :scope => :sub, :base => 'dc=acme,dc=com'
			end
			serviceclass.ldap_dn_search.should == {
				:filter => TEST_FILTER_PATTERN,
				:scope  => :sub,
				:base   => 'dc=acme,dc=com'
			}
		end

		it "provides a declarative to set an optional authorization callback for the service" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_authz_callback do |user, directory|
					# noop
				end
			end
			serviceclass.ldap_authz_callback.should be_a( Proc )
		end

		it "accepts the name of a method to call as the authorization callback for the service" do
			serviceclass = Class.new( DRbService ) do
				include DRbService::LDAPAuthentication
				ldap_authz_callback :authorize_user
			end
			serviceclass.ldap_authz_callback.should == :authorize_user
		end


		describe "instances without an ldap URI set" do

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


			it "raise an exception without calling the block on any authentication" do
				block_called = false
				expect {
					@serviceobj.authenticate( '' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication failure/i )
				block_called.should == false
			end

			it "don't allow access to guarded methods" do
				expect {
					@serviceobj.do_some_guarded_stuff
				}.to raise_exception( SecurityError, /not authenticated/i )
			end

			it "allow access to unguarded methods" do
				@serviceobj.do_some_unguarded_stuff.should == 'Adonk.'
			end

		end

		describe "instances with an ldap_dn pattern set" do

			before( :each ) do
				@serviceclass = Class.new( DRbService ) do
					include DRbService::LDAPAuthentication

					ldap_uri TEST_URI
					ldap_dn 'uid=%s,ou=people,dc=acme,dc=com'

					def do_some_guarded_stuff; return "Ronk."; end
					unguarded do
						def do_some_unguarded_stuff; return "Adonk."; end
					end
				end
			end

			before( :each ) do
				@serviceobj = @serviceclass.new
			end


			it "uses the ldap_dn as a pattern for authentication" do
				directory = mock( "directory object" )
				user_branch = mock( "user branch" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				Treequel::Branch.should_receive( :new ).
					with( directory, 'uid=user,ou=people,dc=acme,dc=com' ).
					and_return( user_branch )
				user_branch.should_receive( :exists? ).and_return( true )

				directory.should_receive( :bind_as ).
					with( user_branch, 'pass' ).
					and_raise( LDAP::ResultError.new('Invalid credentials') )

				block_called = false
				expect {
					@serviceobj.authenticate( 'user', 'pass' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication fail/i )
				block_called.should == false
			end

			it "fails if the DN isn't valid" do
				directory = mock( "directory object" )
				user_branch = mock( "user branch" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				Treequel::Branch.should_receive( :new ).
					with( directory, 'uid=user,ou=people,dc=acme,dc=com' ).
					and_return( user_branch )
				user_branch.should_receive( :exists? ).and_return( false )

				directory.should_not_receive( :bind_as )

				block_called = false
				expect {
					@serviceobj.authenticate( 'user', 'pass' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication fail/i )
				block_called.should == false
			end

		end

		describe "instances with an ldap_dn_search set" do

			before( :each ) do
				@serviceclass = Class.new( DRbService ) do
					include DRbService::LDAPAuthentication

					ldap_uri TEST_URI
					ldap_dn_search TEST_FILTER_PATTERN,
						:base => TEST_BASE,
						:scope => :one

					def do_some_guarded_stuff; return "Ronk."; end
					unguarded do
						def do_some_unguarded_stuff; return "Adonk."; end
					end
				end
			end

			before( :each ) do
				@serviceobj = @serviceclass.new
			end


			it "use the configured search criteria to find the user to bind as" do
				directory = mock( "directory object" )
				base_branch = mock( "base branch" )
				user_branch = mock( "user branch" )
				search_branchset = mock( "search branchset" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				Treequel::Branch.should_receive( :new ).with( directory, TEST_BASE ).
					and_return( base_branch )
				base_branch.should_receive( :scope ).with( :one ).and_return( search_branchset )

				expected_filter = TEST_FILTER_PATTERN % [ 'user' ]
				search_branchset.should_receive( :filter ).with( expected_filter ).
					and_return( search_branchset )
				search_branchset.should_receive( :first ).and_return( user_branch )

				directory.should_receive( :bind_as ).with( user_branch, 'pass' ).
					and_raise( LDAP::ResultError.new('Invalid credentials') )

				block_called = false
				expect {
					@serviceobj.authenticate( 'user', 'pass' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication fail/i )
				block_called.should == false
			end

			it "fails if the search can't find a valid user" do
				directory = mock( "directory object" )
				base_branch = mock( "base branch" )
				search_branchset = mock( "search branchset" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				Treequel::Branch.should_receive( :new ).with( directory, TEST_BASE ).
					and_return( base_branch )
				base_branch.should_receive( :scope ).with( :one ).and_return( search_branchset )

				expected_filter = TEST_FILTER_PATTERN % [ 'user' ]
				search_branchset.should_receive( :filter ).with( expected_filter ).
					and_return( search_branchset )
				search_branchset.should_receive( :first ).and_return( nil )

				directory.should_not_receive( :bound_as )

				block_called = false
				expect {
					@serviceobj.authenticate( 'user', 'pass' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authentication fail/i )
				block_called.should == false
			end
		end

		describe "instances with an ldap_authz_callback set to a Proc" do
			before( :each ) do
				@serviceclass = Class.new( DRbService ) do
					include DRbService::LDAPAuthentication

					ldap_uri TEST_URI
					ldap_dn TEST_DN_PATTERN
					ldap_authz_callback do |user, directory|
						user.is_authorized?
					end

					def do_some_guarded_stuff; return "Ronk."; end
					unguarded do
						def do_some_unguarded_stuff; return "Adonk."; end
					end
				end
			end

			before( :each ) do
				@serviceobj = @serviceclass.new
			end

			it "raises a SecurityError if the authorization callback returns false" do
				directory = mock( "directory object" )
				user = mock( "user branch" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				expected_dn = TEST_DN_PATTERN % [ 'user' ]
				Treequel::Branch.should_receive( :new ).with( directory, expected_dn ).
					and_return( user )
				user.should_receive( :exists? ).and_return( true )
				directory.should_receive( :bind_as ).with( user, 'pass' ).
					and_return( expected_dn )
				user.should_receive( :is_authorized? ).and_return( false )

				block_called = false
				expect {
					@serviceobj.authenticate( 'user', 'pass' ) do
						block_called = true
					end
				}.should raise_exception( SecurityError, /authorization fail/i )
				block_called.should == false
			end

			it "yields to the remote caller if the authorization callback returns true" do
				directory = mock( "directory object" )
				user = mock( "user branch" )

				Treequel.should_receive( :directory ).with( TEST_URI ).
					and_return( directory )
				expected_dn = TEST_DN_PATTERN % [ 'user' ]
				Treequel::Branch.should_receive( :new ).with( directory, expected_dn ).
					and_return( user )
				user.should_receive( :exists? ).and_return( true )
				directory.should_receive( :bind_as ).with( user, 'pass' ).
					and_return( expected_dn )
				user.should_receive( :is_authorized? ).and_return( true )

				block_called = false
				@serviceobj.authenticate( 'user', 'pass' ) do
					block_called = true
				end
				block_called.should == true
			end
		end

	end

end

