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


 	### Authenticate using the specified +password+, calling the provided block if 
	### authentication succeeds. Raises a SecurityError if authentication fails. If
	### no password is set, the block is called regardless of what the +password+ is.
	def authenticate( user, password )
		uri = self.class.ldap_uri
		directory = Treequel.directory( uri )
		user_branch = self.find_auth_user( directory, user )

		directory.bound_as( user_branch, password ) do
			@authenticated = true
			if @ldap_authz_callback
				yield if self.call_authz_callback( user_branch, directory )
			else
				yield
			end
		end

		# If the block exits and authenticated isn't still set, then
		# authentication failed.
		super unless @authenticated
	ensure
		@authenticated = false
	end


	#########
	protected
	#########

	### Find the specified +user+ entry in the given +directory+ and return a 
	### Treequel::Branch for it.
	def find_auth_user( directory, user )
		if dnpattern = self.class.ldap_dn
			dn = dnpattern % [ user ]
			return Treequel::Branch.new( directory, dn )
		else
			dnsearch = self.class.ldap_dn_search
			usersearch = dnsearch[:base] ?
				Treequel::Branch.new( directory, dnsearch[:base] ) :
				directory.base
			usersearch = usersearch.scope( dnsearch[:scope] ) if dnsearch[:scope]
			return usersearch.filter( dnsearch[:filter] % [user] ).first
		end
	end


	### Call the authorization callback with the given +user+ and +directory+ and
	### return true if it indicates authorization was successful. 
	def call_authz_callback( user, directory )
		if @ldap_authz_callback.respond_to?( :call )
			return true if @ldap_authz_callback.call( user, directory )
		else callback = self.method( @ldap_authz_callback )
			return true if callback.call( user, directory )
		end
	end

end # DRbService::LDAPAuthentication


