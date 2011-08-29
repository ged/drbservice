#!/usr/bin/env ruby

require 'fileutils'

require 'drbservice'
require 'drbservice/ldapauth'

# An example service that provides functions that operate from a
# root-trusted host to make changes to a network storage server from
# unprivileged hosts.
class HomeDirService < DRbService
	include DRbService::LDAPAuthentication

	# Home directory Pathname
	HOMEDIR_BASE = Pathname( '/mnt/storage/acme/home' )

	# Archived homedir path
	ARCHIVE_BASE = HOMEDIR_BASE + '__archived'

	# Skeldir path
	SKELDIR = HOMEDIR_BASE + '__skel'


	# Configure LDAP authentication
	ldap_uri 'ldap://ldap.acme.com/dc=acme,dc=com'
	ldap_dn_search 'uid=%s',
		:base => 'ou=employees,dc=acme,dc=com',
		:scope => :one

	# Authorize users who are in the posixGroup called 'sysadmin' under ou=groups
	ldap_authz_callback do |directory, bound_user|
		sysadmin_group = directory.ou( :groups ).cn( :sysadmin )
		return bound_user[:active] &&
			sysadmin_group[:memberUids].include?( bound_user[:uid].first )
	end


	### Define some methods that can be called without authenticating
	unguarded do

		### Returns +true+ if either an active home directory or an archived home 
		### directory for +username+ currently exists.
		def homedir_exists?( username )
			self.active_homedir_exists?( username ) ||
				self.archived_homedir_exists?( username )
		end

		### Returns +true+ if an active home directory for +username+ currently
		### exists.
		def active_homedir_exists?( username )
			homedir = HOMEDIR_BASE + username
			return homedir.directory?
		end

		### Returns +true+ if an archived home directory for +username+ currently
		### exists.
		def archived_homedir_exists?( username )
			archived_homedir = ARCHIVE_BASE + username
			return archived_homedir.directory?
		end

	end # unguarded


	### Make a new home directory for +username+, cloned from the given +skeldir+.
	def make_home_directory( username, skeldir=SKELDIR )
		self.log.info "Making home directory for %p, cloned from %s" % [ username, skeldir ]
		homedir = HOMEDIR_BASE + username
		raise "%s: already exists" % [ homedir ] if homedir.exist?
		raise "%s: already has an archived homedir" % [ username ] if
			( ARCHIVE_BASE + username ).exist?

		FileUtils.cp_r( skeldir.to_s, homedir )
		FileUtils.chown_R( username, nil, homedir )

		return homedir.to_s
	end


	### Move a user's home directory to the archive directory
	def archive_home_directory( username )
		self.log.info "Archiving home directory for %p" % [ username ]
		homedir = HOMEDIR_BASE + username
		archivedir = ARCHIVE_BASE + username
		raise "#{username}: no current home directory" unless homedir.exist?
		raise "#{username}: already has an archived home" if archivedir.exist?

		FileUtils.mv( homedir, archivedir )
	end


	### Move a user's archived home directory back to the active directory.
	def unarchive_home_directory( username )
		self.log.info "Unarchiving home directory for %p" % [ username ]
		homedir = HOMEDIR_BASE + username
		archivedir = ARCHIVE_BASE + username
		raise "#{username}: already has an unarchived home directory" if homedir.exist?
		raise "#{username}: no archived home" unless archivedir.exist?

		FileUtils.mv( archivedir, homedir )
	end

end # HomeDirService

HomeDirService.start(
	:ip       => '127.0.0.1',
	:port     => 4848, 
	:certfile => 'service-cert.pem',
	:keyfile  => 'service-key' )

