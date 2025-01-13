# sbsm

* https://github.com/zdavatz/sbsm

## DESCRIPTION:

Application framework for state based session management. See lib/sbsm.rb

## FEATURES/PROBLEMS:

* Open problems
    * There is no real integration test using rack-test to prove that a minimal app is working
    * Handling redirects is not tested (and probably will not work)
    * Handling passthru is not tested (and probably will not work)
    * I get often the error `Errno::EACCES at / Permission denied @ rb_sysopen - /tmp/sbsm_lock`. Reloading the page once or twices fixes the problem.

## REQUIREMENTS:

* Ruby 2.6

## INSTALL:

* gem install sbsm

or

De-Compress archive and enter its top directory. Then type:

* gem install bundler
* bundle exec rake install:local

You can also install files into your favorite directory by supplying setup.rb some options. Try "ruby setup.rb --help".

## TESTING

* bundle exec rake test

## DEVELOPERS:

* Masaomi Hatakeyama
* Zeno Davatz
* Hannes Wyss (upto Version 1.0)
* Niklaus Giger (Port to Ruby 2.3.0..3.4.0)

## LICENSE:

* GPLv2.1
