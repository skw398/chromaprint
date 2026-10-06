#!/bin/sh
# Fork-only installed-consumer check. The C++ driver supplies the runtime;
# this isolates FFT dependencies from the separate runtime proposal (#119).
set -eu
export LC_ALL=C

case "$FFT_LIB" in
    avtx) expected_requires=libavutil; failure_pattern='av_tx_' ;;
    avfft) expected_requires='libavcodec libavutil'; failure_pattern='av_rdft_' ;;
    fftw3) expected_requires=fftw3; failure_pattern='fftw_' ;;
    fftw3f) expected_requires=fftw3f; failure_pattern='fftwf_' ;;
    kissfft) expected_requires=''; failure_pattern='' ;;
    vdsp) expected_requires=''; failure_pattern='vDSP_' ;;
    *) echo 'ERROR: invalid FFT backend' >&2; exit 1 ;;
esac

root=$RUNNER_TEMP/chromaprint-pkgconfig-$FFT_LIB
test_dir=$GITHUB_WORKSPACE/candidate/.github/tests/pkgconfig-fft-dependencies
mkdir -p "$root"
for variant in baseline candidate; do
    for shared in OFF ON; do
        build=$root/$variant-$shared-build
        prefix=$root/$variant-$shared-install
        tests=OFF
        if [ "$variant" = candidate ]; then tests=ON; fi
        disable_ffmpeg=ON
        case "$FFT_LIB" in avtx|avfft) disable_ffmpeg=OFF ;; esac
        cmake -S "$GITHUB_WORKSPACE/$variant" -B "$build" \
            -DCMAKE_BUILD_TYPE=Release -DFFT_LIB="$FFT_LIB" \
            -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
            -DBUILD_SHARED_LIBS="$shared" -DBUILD_TESTS="$tests" -DBUILD_TOOLS=OFF \
            -DCMAKE_DISABLE_FIND_PACKAGE_FFmpeg="$disable_ffmpeg" \
            -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib
        cmake --build "$build" --parallel 4
        if [ "$variant" = candidate ]; then
            ctest --test-dir "$build" --output-on-failure --no-tests=error
        fi
        cmake --install "$build"
        export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
        test "$(pkg-config --variable=prefix libchromaprint)" = "$prefix"
        pkg-config --validate libchromaprint
        cat "$prefix/lib/pkgconfig/libchromaprint.pc"
        cflags=$(pkg-config --cflags libchromaprint)
        normal_flags=$(pkg-config --libs libchromaprint)
        static_flags=$(pkg-config --static --libs libchromaprint)
        printf '%s/%s ordinary flags: %s\n' "$variant" "$shared" "$normal_flags"
        printf '%s/%s static flags: %s\n' "$variant" "$shared" "$static_flags"
        normal_libraries=$(pkg-config --libs-only-l libchromaprint)
        test "$(printf '%s' "$normal_libraries" | xargs)" = '-lchromaprint'
        case "$normal_flags" in
            *Accelerate*) echo 'ERROR: private framework leaked into ordinary flags' >&2; exit 1 ;;
        esac
        if [ "$variant" = candidate ]; then
            printf '%s' "$expected_requires" | tr ' ' '\n' | sed '/^$/d' | sort > "$root/expected-requires"
            pkg-config --print-requires-private libchromaprint | sort > "$root/actual-requires"
            diff -u "$root/expected-requires" "$root/actual-requires"
            if [ "$FFT_LIB" = vdsp ]; then
                case "$static_flags" in
                    *'-framework Accelerate'*) ;;
                    *) echo 'ERROR: missing Accelerate' >&2; exit 1 ;;
                esac
            fi
        fi
        # Intentional flag splitting; the CI prefix has no whitespace.
        "$CC" $cflags -c "$test_dir/consumer.c" -o "$build/consumer.o"
        if [ "$shared" = OFF ]; then
            test -f "$prefix/lib/libchromaprint.a"
            flags=$static_flags
        else
            flags=$normal_flags
        fi
        if [ "$variant" = baseline ] && [ "$shared" = OFF ] && [ "$FFT_LIB" != kissfft ]; then
            if "$CXX" "$build/consumer.o" $flags -o "$build/consumer" > "$build/link.log" 2>&1; then
                echo 'ERROR: unmodified external-FFT static consumer unexpectedly linked' >&2
                exit 1
            fi
            cat "$build/link.log"
            grep -E 'undefined reference|Undefined symbols' "$build/link.log"
            grep -E "$failure_pattern" "$build/link.log"
            echo "ok: baseline/$FFT_LIB static link fails on missing FFT symbols"
            continue
        fi
        "$CXX" "$build/consumer.o" $flags -Wl,-rpath,"$prefix/lib" -o "$build/consumer"
        if [ "$shared" = ON ]; then
            case "$(uname -s)" in
                Linux)
                    ldd "$build/consumer" > "$build/loaded-libraries"
                    grep -F "$prefix/lib/libchromaprint.so" "$build/loaded-libraries"
                    "$build/consumer" > "$build/fingerprint" ;;
                Darwin)
                    DYLD_PRINT_LIBRARIES=1 "$build/consumer" > "$build/fingerprint" 2> "$build/loaded-libraries"
                    grep -F "$prefix/lib/libchromaprint" "$build/loaded-libraries" ;;
                *) echo 'ERROR: unsupported runner' >&2; exit 1 ;;
            esac
        else
            "$build/consumer" > "$build/fingerprint"
        fi
        cat "$build/fingerprint"
        echo "ok: $variant/$FFT_LIB/shared=$shared consumer links, runs, and matches the existing silence fingerprint"
    done
done
