#!/usr/bin/env bash

jruby+truffle setup || exit $?

OVERALL_EXIT_CODE=0

for SPEC in atomic \
            channel \
            collection \
            concern \
            executor \
            thread_safe \
            utility \
            *_spec.rb
do
  NO_COVERAGE=1 jruby+truffle --no-use-fs-core --verbose run -S rspec -- \
    -J-Xmx2G -- spec/concurrent/$SPEC --format documentation \
    --tag ~unfinished --seed 1 --tag ~notravis --tag ~buggy --tag ~truffle_bug
  EXIT_CODE=$?
  if [[ $EXIT_CODE != 0 ]]
  then
    OVERALL_EXIT_CODE=1
  fi
done

exit $OVERALL_EXIT_CODE
