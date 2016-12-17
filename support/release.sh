#!/usr/bin/env bash

set -e

if [[ pitr != $(whoami) ]]
then
    echo "!!! This script takes a lot of assumptions based on @pitr-ch's environment."
    echo "!!! Use it at your own risk."
fi


version=$(ruby -r concurrent/version -e 'puts Concurrent::VERSION')
edge_version=$(ruby -r concurrent/version -e 'puts Concurrent::EDGE_VERSION')
(echo ${version} | grep pre) && prerelease='true' || prerelease='false'

echo "concurrent-ruby:      $version"
echo "concurrent-ruby-edge: $edge_version"
echo "prerelease:           $prerelease"

set -x

mriVersion="2.3.1"
jrubyVersion="jruby-9.1.5.0"

if [[ "$@" =~ 'build' || $@ =~ 'all' ]]
then
    echo Building

    export RBENV_VERSION=$mriVersion
    docker-machine status | grep Running || docker-machine start
    eval $(docker-machine env --shell sh default)
    rbenv version
    bundle install
    bundle exec rake clean
    bundle exec rake build
    docker-machine stop

    export RBENV_VERSION=$jrubyVersion
    rbenv version
    rm Gemfile.lock || true
    bundle install
    bundle exec rake clean
    bundle exec rake build
fi

if [[ "$@" =~ "test" || $@ =~ 'all' ]]
then
    cd ..
    # TODO (pitr-ch 17-Dec-2016): dry: duplicates rake task
    rspec_options='--color --backtrace --seed 1 --format documentation --tag ~unfinished --tag ~notravis --tag ~buggy'

    # Install and test MRI version
    export RBENV_VERSION=$mriVersion
    gem install concurrent-ruby/pkg/concurrent-ruby-${version}.gem
    gem install concurrent-ruby/pkg/concurrent-ruby-edge-${edge_version}.gem
    gem install concurrent-ruby/pkg/concurrent-ruby-ext-${version}.gem
    ruby -r concurrent-edge -I concurrent-ruby/spec -r spec_helper -S rspec concurrent-ruby/spec ${rspec_options}
    gem uninstall concurrent-ruby-ext --version ${version}
    gem uninstall concurrent-ruby-edge --version ${edge_version}
    gem uninstall concurrent-ruby --version ${version}


    # Install and test JRuby version
    export RBENV_VERSION=$jrubyVersion
    gem push concurrent-ruby/pkg/concurrent-ruby-${version}-java.gem
    gem install concurrent-ruby/pkg/concurrent-ruby-edge-${edge_version}.gem
    ruby -r concurrent-edge -S rspec concurrent-ruby/spec ${rspec_options}
    gem uninstall concurrent-ruby-edge --version ${edge_version}
    gem uninstall concurrent-ruby --version ${version}

    cd concurrent-ruby

    # TODO (pitr-ch 17-Dec-2016): test windows build
fi

if [[ "$@" =~ "push" || $@ =~ 'all' ]]
then
    echo Pushing

    # Test that we are on pushed commit
    git fetch
    test -z "$(git log --oneline master..upstream/master)"
    test -z "$(git log --oneline upstream/master..master)"

    # Tags
    git tag "v${version}"
    git tag "edge-v${edge_version}"
    git push --tags

    # TODO (pitr-ch 16-Dec-2016): Release
    # https://developer.github.com/v3/repos/releases/#create-a-release
    # token=$(cat .githubtoken)
    #curl -X POST \
    #    -H "Authorization: token ${token}" \
    #    -H "Content-Type: application/json" \
    #    -H "Cache-Control: no-cache" \
    #    -d "{
    #          \"tag_name\": \"v0.1\",
    #          \"target_commitish\": \"master\",
    #          \"name\": \"v0.1\",
    #          \"body\": \"Description of the release\",
    #          \"draft\": true,
    #          \"prerelease\": ${prerelease}
    #        }" \
    #    "https://api.github.com/repos/pitr-ch/concurrent-ruby/releases"

    # Push to rubygems
    gem push pkg/concurrent-ruby-1.0.3.gem
    gem push pkg/concurrent-ruby-1.0.3-java.gem
    gem push pkg/concurrent-ruby-edge-0.2.3.gem
    gem push pkg/concurrent-ruby-ext-1.0.3.gem
    gem push pkg/concurrent-ruby-ext-1.0.3-x64-mingw32.gem
    gem push pkg/concurrent-ruby-ext-1.0.3-x86-mingw32.gem

    # TODO (pitr-ch 17-Dec-2016): send email
fi



