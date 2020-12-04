
if [ -z $MRB_BUILDDIR ]; then
  echo "You must have an MRB area set up to use this script!"
  exit 1
fi

if ! [[ $MRB_QUALS =~ debug ]]; then
  echo "This script only works for Debug builds!"
  exit 2
fi

pushd $MRB_BUILDDIR

USE_GCOV=1
ninja -j$CETPKG_J;

lcov -d . --zerocounters
lcov --ignore-errors gcov -c -i -d . -o ${MRB_PROJECT}.base

CTEST_PARALLEL_LEVEL=${CETPKG_J} ninja -j$CETPKG_J test || exit 3

lcov --ignore-errors gcov -d . --capture --output-file ${MRB_PROJECT}.info
lcov -a ${MRB_PROJECT}.base -a ${MRB_PROJECT}.info --output-file ${MRB_PROJECT}.total
lcov --remove ${MRB_PROJECT}.total */products/* */build_${CET_SUBDIR}/* /usr/include/curl/* --output-file ${MRB_PROJECT}.info.cleaned
genhtml -o coverage ${MRB_PROJECT}.info.cleaned

popd
