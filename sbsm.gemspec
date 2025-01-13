lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sbsm/version"

Gem::Specification.new do |spec|
  spec.name = "sbsm"
  spec.version = SBSM::VERSION
  spec.author = "Masaomi Hatakeyama, Zeno R.R. Davatz"
  spec.email = "mhatakeyama@ywesee.com, zdavatz@ywesee.com"
  spec.description = "Application framework for state based session management"
  spec.summary = "Application framework for state based session management from ywesee"
  spec.homepage = "https://github.com/zdavatz/sbsm"
  spec.license = "GPL-v2"
  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/ChangeLog"
  spec.required_ruby_version = '>= 2.5'

  # We fix the version of the spec to newer versions only in the third position
  # hoping that these version fix only security/severe bugs
  # Consulted the Gemfile.lock to get
  spec.add_dependency "rack"
  spec.add_dependency "mail", "< 2.8.0"
  spec.add_dependency "nokogiri"
  spec.add_dependency "mimemagic"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "flexmock"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "e2mmap"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "watir"
  spec.add_development_dependency "watir-webdriver"
  spec.add_development_dependency "debug"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "nokogiri"
  spec.add_development_dependency "rack-test"
end
