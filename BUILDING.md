# Building

All published versions of this gem (core, extension, and several platform-specific packages) are compiled,
packaged, tested, and published using an open, automated process.
This process can also be used to create pre-compiled binaries of the extension gem for virtually
any platform. *Documentation is forthcoming...*

```
*MRI only*
bundle exec rake build:native       # Build concurrent-ruby-ext-<version>-<platform>.gem into the pkg dir
bundle exec rake compile:extension  # Compile extension

*JRuby only*
bundle exec rake build              # Build JRuby-specific core gem (alias for `build:core`)
bundle exec rake build:core         # Build concurrent-ruby-<version>-java.gem into the pkg directory

*All except JRuby*
bundle exec rake build:core         # Build concurrent-ruby-<version>.gem into the pkg directory
bundle exec rake build:ext          # Build concurrent-ruby-ext-<version>.gem into the pkg directory

*When Docker IS installed*
bundle exec rake build:windows      # Build the windows binary <version> gems per rake-compiler-dock
bundle exec rake build              # Build core, extension, and edge gems, including Windows binaries

*When Docker is NOT installed*
bundle exec rake build              # Build core, extension, and edge gems (excluding Windows binaries)

*All*
bundle exec rake clean              # Remove any temporary products
bundle exec rake clobber            # Remove any generated file
bundle exec rake compile            # Compile all the extensions
```

## Publishing the Gem

To create the build you'll need to have both MRI and JRuby installed and configured with the appropriate build tools and libraries. To create the Windows build you'll need to install docker. If you are on OS X you'll also need boot2docker. Once you have all that setup, everything if fairly automated:

* Update`version.rb`
* Update the CHANGELOG
* Switch to MRI
  - Make sure docker is running (otherwise the windows build task will not be available)
  - Run `bundle exec rake clean` to get rid of old artifacts
  - Run `bundle exec rake build` to build core, ext, ext-windows, and edge into the *pkg* directory
* Switch to JRuby
  - Delete *Gemfile.lock* and run `bundle install` (this isn't always necessary, but our multi-gem setup sometimes confuses bundler)
  - Run `bundle exec rake clean` to get rid of old artifacts
  - Run `bundle exec rake build` to build core-java into the *pkg* directory
* If everything looks good, update git
  - Commit the changes
  - Tag the master branch with the version number
  - Push to GitHub
* Update the Yard documentation
  - Run `bundle exec rake yard` to update the documentation
  - Run `bundle exec rake yard:push` to push the docs to GitHub Pages
* For each gem file in *pkg* run `gem push pkg/concurrent-ruby-<...>.gem` to push to Rubygems
* Update the release in GitHub
  - Select the `releases` link on the main repo page
  - Press the `Edit` button to edit the release
  - Name the release based on the version number
  - Add a description
  - Attach all the `*.gem` file
  - Save the updated release

The compiled and build gem packages can be tested using the scripts in the `build-tests` folder. The `runner.rb` script is the main test runner. It will run all tests which are available on the given platform. It will install the various gem packages (core, ext, and edge) as necessary, run the tests, then clean up after itself.
