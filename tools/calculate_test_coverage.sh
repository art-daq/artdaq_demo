#!/bin/bash

# lcov has to be installed manually -- 
# https://github.com/linux-test-project/lcov/releases/tag/v1.15
# lcov-1.15-1.noarch.rpm

# Upon success, the output will be in $MRB_BUILDDIR/converage
# Load the file $MRB_BUILDDIR/converage/index.html in your browser.

if [ -z $MRB_BUILDDIR ]; then
  echo "You must have an MRB area set up to use this script!"
  exit 1
fi

if ! [[ $MRB_QUALS =~ debug ]]; then
  echo "This script only works for Debug builds!"
  exit 2
fi

pushd $MRB_BUILDDIR

export USE_GCOV=1

if [ -f build.ninja ]; then
    ninja -j$CETPKG_J || exit 3
else
    mrb b || exit 3
fi

lcov -d . --zerocounters
lcov --ignore-errors gcov -c -i -d . -o ${MRB_PROJECT}.base

# RUN THE TESTS
if [ -f build.ninja ]; then
    CTEST_PARALLEL_LEVEL=${CETPKG_J} ninja -j$CETPKG_J test || exit 4
else
    mrb t || exit 4
fi

lcov --ignore-errors gcov -d . --capture --output-file ${MRB_PROJECT}.info
lcov -a ${MRB_PROJECT}.base -a ${MRB_PROJECT}.info --output-file ${MRB_PROJECT}.total
lcov --remove ${MRB_PROJECT}.total */products/* */build_${CET_SUBDIR}/* /usr/include/curl/* --output-file ${MRB_PROJECT}.info.cleaned
genhtml -o coverage ${MRB_PROJECT}.info.cleaned

popd
