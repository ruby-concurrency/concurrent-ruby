# Building

```
bundle exec rake clobber        # clean
bundle exec rake repackage      # all 3 gems without windows builds
bundle exec rake repackage:all  # all 3 gems with the fat windows builds (requires docker)
```

## Publishing the Gem

To create the build you'll need to have both MRI and JRuby installed and configured with the appropriate build tools and libraries. To create the Windows build you'll need to install docker. If you are on OS X you'll also need boot2docker. Once you have all that setup, everything if fairly automated:

* Update`version.rb`
* Update the CHANGELOG
* Switch to MRI
  - Run `bundle exec rake clobber` to get rid of old artifacts
  - Run `bundle exec rake repackage:all` to build core, ext, ext-windows, and edge into the *pkg* directory
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
