#!/usr/bin/env bash

set -x
set -e

bundle install --local

# # Uncomment to build jar in docker
# sudo apt-get update
# sudo apt-get install -y openjdk-8-jdk-headless
# sudo -u rvm bash -ic 'rvm install jruby-9.1.13.0'
# export JRUBY_HOME=/usr/local/rvm/rubies/jruby-9.1.13.0
#
# bundle exec rake cross clobber native package clean --trace

bundle exec rake cross native package --trace
