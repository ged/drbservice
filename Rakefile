#!/usr/bin/env rake

require 'hoe'

Hoe.plugin :mercurial
Hoe.plugin :yard
Hoe.plugin :signing

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'drbservice' do
	self.readme_file = 'README.md'
	self.history_file = 'History.md'

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.extra_dev_deps.push *{
		'rspec' => '~> 2.4',
	}

	self.spec_extras[:licenses] = ["BSD"]
	self.spec_extras[:post_install_message] = %{

		This library isn't really ready for production use yet, but
		feel free to experiment with it.
		
	}.gsub( /^\t{2}/, '' )

	self.require_ruby_version( '>=1.8.7' )

	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

