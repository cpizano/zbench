#!/bin/bash

# Script to build and benchmark with both the old and new version of the
# standard library.
#
# Must be run from the zbench root dir.
set -e

path_old=zig-out/old
path_new=zig-out/new
bin_old=$path_old/bin/zbench
bin_new=$path_new/bin/zbench

# Build both versions. if not there.
if [ ! -f "$bin_new" ]; then
echo "build new version."
zig build --release=fast  --zig-lib-dir /Users/cpu/src/zig/lib --prefix "$path_new"
fi

if [ ! -f "$bin_old" ]; then
echo "build old version."
zig build --release=fast --prefix "$path_old"
fi

# Run both versions using the "background" policy for MacOS which should
# restrict to using the efficiency cores.
echo "new:"
taskpolicy -b "$bin_new"
echo "old:"
taskpolicy -b "$bin_old"

echo "done."
