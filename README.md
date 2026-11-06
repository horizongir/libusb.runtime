# libusb.runtime

Unofficial NuGet distribution of the native runtime binaries of [libusb](https://libusb.info), a C library for generic access to USB devices.

A project that references the package gets the native libusb library of the same version, matching its platform and architecture, with no separate libusb installation. On Windows, the library needs the [latest Microsoft Visual C++ Redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist).

## Usage

```
dotnet add package libusb.runtime
```

## License

libusb is licensed under the [GNU Lesser General Public License, version 2.1](https://github.com/libusb/libusb/blob/master/COPYING) or any later version. The package includes the license text and a notice pointing to the source of the release it contains.

This project is not affiliated with the libusb project. Report problems with libusb itself to [libusb/libusb](https://github.com/libusb/libusb/issues).
