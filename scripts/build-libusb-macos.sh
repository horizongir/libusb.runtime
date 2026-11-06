#!/usr/bin/env bash
set -euo pipefail

deployment_target="$1"
mkdir -p "$2"
output_directory="$(cd "$2" && pwd)"
archive_name="$(basename "$LIBUSB_SOURCE_URL")"
version="${archive_name#libusb-}"
version="${version%.tar.bz2}"
architecture="$(uname -m)"
work_directory="$(mktemp -d)"

curl --fail --silent --show-error --location --output "$work_directory/$archive_name" "$LIBUSB_SOURCE_URL"
echo "$LIBUSB_SOURCE_SHA256  $work_directory/$archive_name" | shasum --algorithm 256 --check --strict
tar -xjf "$work_directory/$archive_name" -C "$work_directory"

cd "$work_directory/libusb-$version"
export MACOSX_DEPLOYMENT_TARGET="$deployment_target"
./configure --prefix="$work_directory/install" --disable-static
make -j"$(sysctl -n hw.ncpu)"
make install

library="$output_directory/libusb-1.0.dylib"
cp "$work_directory/install/lib/libusb-1.0.0.dylib" "$library"
install_name_tool -id @rpath/libusb-1.0.dylib "$library"
codesign --force --sign - "$library"

architectures="$(lipo -archs "$library")"
install_name="$(otool -D "$library" | tail -n 1)"
minimum_os="$(vtool -show-build "$library" | awk '$1 == "minos" { print $2 }')"
dependencies="$(otool -L "$library" | tail -n +3 | awk '{ print $1 }')"
echo "Architectures: $architectures"
echo "Install name: $install_name"
echo "Minimum macOS: $minimum_os"
echo "Dependencies:"
echo "$dependencies"

codesign --verify --strict "$library"
test "$architectures" = "$architecture"
test "$install_name" = "@rpath/libusb-1.0.dylib"
test "$minimum_os" = "$deployment_target"
test -z "$(echo "$dependencies" | grep -v -E '^(/usr/lib/|/System/Library/)' || true)"

python3 - "$library" "$version" <<'PYTHON'
import ctypes
import sys

class Version(ctypes.Structure):
    _fields_ = [
        ("major", ctypes.c_uint16),
        ("minor", ctypes.c_uint16),
        ("micro", ctypes.c_uint16),
        ("nano", ctypes.c_uint16),
        ("rc", ctypes.c_char_p),
        ("describe", ctypes.c_char_p),
    ]

library = ctypes.CDLL(sys.argv[1])
library.libusb_get_version.restype = ctypes.POINTER(Version)
library.libusb_get_device_list.restype = ctypes.c_ssize_t

version = library.libusb_get_version().contents
loaded = f"{version.major}.{version.minor}.{version.micro}"
if loaded != sys.argv[2]:
    sys.exit(f"Loaded libusb {loaded}, expected {sys.argv[2]}")

context = ctypes.c_void_p()
result = library.libusb_init(ctypes.byref(context))
if result != 0:
    sys.exit(f"libusb_init returned {result}")

devices = ctypes.POINTER(ctypes.c_void_p)()
count = library.libusb_get_device_list(context, ctypes.byref(devices))
if count < 0:
    sys.exit(f"libusb_get_device_list returned {count}")

library.libusb_free_device_list(devices, 1)
library.libusb_exit(context)
print(f"Loaded libusb {loaded}, initialized it and listed {count} devices")
PYTHON
