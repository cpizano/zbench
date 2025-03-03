# bash

# Must be run from the zbench root dir.

# Build both versions.
zig build --release=fast  --zig-lib-dir /Users/cpu/src/zig/lib --prefix zig-out/new
zig build --release=fast --prefix zig-out/old

# Run each.
echo "new:"
zig-out/new/bin/zbench
echo "old:"
zig-out/old/bin/zbench
