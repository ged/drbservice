#!/usr/bin/env ruby

require 'drb'
require 'drb/ssl'

# A base class for DRb-based services.

class DRbService
	include DRbUndumped

	# Library version
	VERSION = '1.0.0'

	# Version-control revision
	REVISION = %$Rev$

	require 'drbservice/utils'
	include DRbService::Logging


	# The container for obscured methods
	@@real_methods = {}


	### Start the DRbService at the given +uri+ and join on its thread.
	def self::start( uri, config={} )
		frontobj = self.new
		DRbService.log.info "Starting %p as a DRbService at %s with config: %p" % [ self, uri, config ]
		DRb.start_service( uri, frontobj, config )
		DRbService.log.debug "  started. Joining the DRb thread."
		DRb.thread.join
	end


	### Obscure any instance method added while not in 'unguarded' mode.
	def self::method_added( meth )
		super
		unless self == ::DRbService || meth.to_sym == :initialize
			if self.unguarded_mode
				DRbService.log.debug "Not obscuring %p#%s: unguarded mode." % [ self, meth ]
			else
				DRbService.log.debug "Obscuring %p#%s." % [ self, meth ]
				@@real_methods[ self ] ||= {}
				@@real_methods[ self ][ meth.to_sym ] = self.instance_method( meth )
				remove_method( meth )
			end
		end
	end


	### Add a per-class 'unguarded mode' flag to subclasses.
	def self::inherited( subclass )
		super
		subclass.instance_variable_set( :@unguarded_mode, false )
	end


	### Declare some service methods that can be called without authentication in
	### the provided block.
	def self::unguarded
		self.unguarded_mode = true
		yield
	ensure
		self.unguarded_mode = false
	end


	### Class accessors
	class << self
		attr_accessor :unguarded_mode
	end


end # class DRbService


