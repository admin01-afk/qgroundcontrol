#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/qgroundcontrol"
BUILD="$REPO/build"
JOBS=8

cd "$REPO"

# If build dir missing or broken, reconfigure
if [ ! -f "$BUILD/build.ninja" ] || [ ! -d "$BUILD/CMakeFiles" ]; then
  echo "Configuring build directory..."
  rm -rf "$BUILD"
  mkdir -p "$BUILD"
  CC=/usr/bin/gcc CXX=/usr/bin/g++ CCACHE_DISABLE=1 \
    cmake -S "$REPO" -B "$BUILD" -GNinja \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DQt6_DIR=/home/mehmet/Qt/6.10.0/gcc_64/lib/cmake/Qt6 \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
fi

# Build only the QGroundControl target
ninja -C "$BUILD" -j${JOBS} QGroundControl

# Run the binary (try the usual locations)
"$BUILD/RelWithDebInfo/QGroundControl"
