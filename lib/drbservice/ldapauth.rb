#!/usr/bin/env ruby
# coding: utf-8

require 'treequel'
require 'drbservice'

# An authentication strategy for DRbService -- set a password via a 
# class method.
module DRbService::LDAPAuthentication

	### Methods added to including classes when LDAPAuthentication is
	### mixed in.
	module ClassMethods

		# The default attributes of a search
		DEFAULT_SEARCH = {
			:filter => 'uid=%s',
			:base   => nil,
			:scope  => :sub,
		}.freeze


		### Extension callback -- add the necessary class instance variables
		### to extended modules.
		def self::extended( mod )
			super
			mod.instance_variable_set( :@ldap_uri, nil )
			mod.instance_variable_set( :@ldap_dn, nil )
			mod.instance_variable_set( :@ldap_dn_search, DEFAULT_SEARCH.dup )
			mod.instance_variable_set( :@ldap_authz_callback, nil )
		end


		### Set the URI of the LDAP server to bind to for authentication
		def ldap_uri( uri=nil )
			@ldap_uri = uri if uri
			return @ldap_uri
		end


		### Set the pattern to use when creating the DN to use when binding.
		def ldap_dn( pattern=nil )
			@ldap_dn = pattern if pattern
			return @ldap_dn
		end


		### Set a filter that is used when searching for an account to bind
		### as.
		def ldap_dn_search( filter=nil, options={} )
			if filter
				@ldap_dn_search ||= {}
				@ldap_dn_search[:filter] = filter
				@ldap_dn_search[:base] = options[:base] if options[:base]
				@ldap_dn_search[:scope] = options[:scope] if options[:scope]
			end

			return @ldap_dn_search
		end


		### Register a function to call when the user successfully binds to the
		### directory to check for authorization. It will be called with the 
		### Treequel::Branch of the bound user and the Treequel::Directory they
		### are bound to. Returning +true+ from this function will cause 
		### authorization to succeed, while returning a false value causes it to 
		### fail.
		def ldap_authz_callback( callable=nil, &block )
			if callable
				@ldap_authz_callback = callable
			elsif block
				@ldap_authz_callback = block
			end

			return @ldap_authz_callback
		end

	end # module ClassMethods


	### Overridden mixin callback -- add the ClassMethods to the including class 
	def self::included( klass )
		super
		klass.extend( ClassMethods )
	end


	### Set up some instance variables used by the mixin.
	def initialize( *args )
		super
		@authenticated	 = false
		@authuser		 = nil
		@authuser_branch = nil
	end


	# @return [String] the username of the authenticated user
	attr_reader :authuser

	# @return [Treequel::Branch] the branch of the authenticated user
	attr_reader :authuser_branch


 	### Authenticate using the specified +password+, calling the provided block if 
	### authentication succeeds. Raises a SecurityError if authentication fails. If
	### no password is set, the block is called regardless of what the +password+ is.
	def authenticate( user, password )
		uri = self.class.ldap_uri
		self.log.debug "Connecting to %p for authentication" % [ uri ]
		directory = Treequel.directory( uri )
		self.log.debug "  finding LDAP record for: %p" % [ user ]
		user_branch = self.find_auth_user( directory, user ) or
			return super

		self.log.debug "  binding as %p (%p)" % [ user, user_branch ]
		directory.bind_as( user_branch, password )
		self.log.debug "  bound successfully..."

		@authenticated = true

		if cb = self.class.ldap_authz_callback
			self.log.debug "  calling authorization callback..."

			unless self.call_authz_callback( cb, user_branch, directory )
				msg = "  authorization failed for: %s" % [ user_branch ]
				self.log.debug( msg )
				raise SecurityError, msg
			end

			self.log.debug "  authorization succeeded."
		end

		@authuser = user
		@authuser_branch = user
		yield

	rescue LDAP::ResultError => err
		self.log.error "  authentication failed for %p" % [ user_branch || user ]
		raise SecurityError, "authentication failure"

	ensure
		@authuser = nil
		@authuser_branch = nil
		@authenticated = false
	end


	#########
	protected
	#########

	### Find the specified +username+ entry in the given +directory+.
	### 
	### @param [Treequel::Directory] directory  the directory to search
	### @param [String] username                the name to use in the search
	### 
	### @return [Treequel::Branch, nil]  the first found user, if one was found
	def find_auth_user( directory, username )
		self.log.debug "Finding the user to bind as."

		if dnpattern = self.class.ldap_dn
			self.log.debug "  using DN pattern %p" % [ dnpattern ]
			dn = dnpattern % [ username ]
			user = Treequel::Branch.new( directory, dn )
			return user.exists? ? user : nil

		else
			dnsearch = self.class.ldap_dn_search
			usersearch = dnsearch[:base] ?
				Treequel::Branch.new( directory, dnsearch[:base] ) :
				directory.base
			usersearch = usersearch.scope( dnsearch[:scope] ) if dnsearch[:scope]
			usersearch = usersearch.filter( dnsearch[:filter] % [username] )

			self.log.debug "  using filter: %s" % [ usersearch ]
			if user = usersearch.first
				self.log.debug "    search found: %s" % [ user ]
				return user
			else
				self.log.error "    search returned no entries" % [ usersearch ]
				return nil
			end
		end

	end


	### Call the authorization callback with the given +user+ and +directory+ and
	### return true if it indicates authorization was successful. 
	def call_authz_callback( callback, user, directory )

		if callback.respond_to?( :call )
			return true if callback.call( user, directory )

		else callback = self.method( callback )
			return true if callback.call( user, directory )
		end

	end

end # DRbService::LDAPAuthentication


