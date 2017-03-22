#!/usr/bin/env ruby
# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sbsm/version'
require "bundler/gem_tasks"
require 'rake/testtask'

config = File.expand_path('../etc/config.yml', __FILE__)
if !File.exist?(config)
  FileUtils.makedirs(File.dirname(config))
  File.open(config, 'w+') {|file| file.puts("---") }
end

# dependencies are now declared in sbsm.gemspec

desc 'Offer a gem task like hoe'
task :gem => :build do
  Rake::Task[:build].invoke
end

task :spec => :clean

require 'rake/clean'
CLEAN.include FileList['pkg/*.gem']

desc "create RDoc documentation"

task :rdoc do
  cmd = "bundle exec rdoc --exclude='/coverage|vendor|test|data|etc|Manifest|.*.lock|.*.css|.*.js|.*.gemspec|.*.patch/' --include=lib" +
      " --main=lib/sbsm.rb --title='SBSM: a framework for state based session management' --op=rdoc"
  puts cmd
  res = system(cmd)
  puts "Running test/suite.rb returned #{res.inspect}. Output is found in the rdoc sub-directory"
  exit 1 unless res
end


desc "Run tests"
task :default => [:gem, :test]

task :test do
  log_file = 'suite.log'
  res = system("bash -c 'set -o pipefail && bundle exec ruby test/suite.rb 2>&1 | tee #{log_file}'")
  puts "Running test/suite.rb returned #{res.inspect}. Output was redirected to #{log_file}"
  exit 1 unless res
end

