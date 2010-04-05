#!/usr/bin/env ruby
# coding: utf-8

require 'digest/sha2'
require 'drbservice'

# An authentication strategy for DRbService -- set a password via a 
# class method.
module DRbService::PasswordAuthentication

	### Methods added to including classes when PasswordAuthentication is
	### mixed in.
	module ClassMethods

		# The SHA2 digest of the service password
		attr_accessor :password_digest

		### Set a password for the service. If you don't specify a password, even guarded
		### methods can be accessed. With a password set, the remote side can still call
		### unguarded methods, but all other methods will be hidden.
		def service_password( password )
			self.password_digest = Digest::SHA2.hexdigest( password )
			DRbService.log.debug "Setting encrypted password for %p to "
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
	def authenticate( password )
		if digest = self.class.password_digest
			if Digest::SHA2.hexdigest( password ) == digest
				self.log.info "authentication successful"
				@authenticated = true
				yield
			else
				super
			end
		else
			self.log.error "no password set -- authentication will always fail"
			super
		end
	ensure
		@authenticated = false
	end

end # DRbService::PasswordAuthentication


