#!/bin/sh
# Build only the FFmpeg libraries used by the install/link regression.
# Avoid distribution .pc files whose private codec dependencies are not installed.
set -eu
mkdir -p "$RUNNER_TEMP/ffmpeg-$FFT_LIB-build"
cd "$RUNNER_TEMP/ffmpeg-$FFT_LIB-build"
set -- --prefix="$FFMPEG_PREFIX" --libdir="$FFMPEG_PREFIX/lib" \
    --cc="$CC" --cxx="$CXX" --disable-everything --disable-autodetect \
    --disable-programs --disable-doc --disable-debug --enable-shared --enable-static \
    --disable-avdevice --disable-avfilter --disable-swscale --disable-swresample
if [ "$FFT_LIB" = avfft ]; then
    set -- "$@" --enable-fft --enable-rdft
fi
"$GITHUB_WORKSPACE/ffmpeg/configure" "$@"
make -j4
make install
export PKG_CONFIG_PATH=$FFMPEG_PREFIX/lib/pkgconfig
pkg-config --modversion libavcodec libavformat libavutil
pkg-config --static --libs libavcodec libavutil
