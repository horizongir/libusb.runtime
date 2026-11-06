using System;
using System.IO;
using System.Runtime.InteropServices;

unsafe
{
    var library = NativeLibrary.Load("libusb-1.0", typeof(Program).Assembly, null);
    var init = (delegate* unmanaged<nint*, int>)NativeLibrary.GetExport(library, "libusb_init");
    var getDeviceList = (delegate* unmanaged<nint, nint**, nint>)NativeLibrary.GetExport(library, "libusb_get_device_list");
    var freeDeviceList = (delegate* unmanaged<nint*, int, void>)NativeLibrary.GetExport(library, "libusb_free_device_list");
    var exit = (delegate* unmanaged<nint, void>)NativeLibrary.GetExport(library, "libusb_exit");
    var getVersion = (delegate* unmanaged<ushort*>)NativeLibrary.GetExport(library, "libusb_get_version");

    var path = GetLibraryPath(library, (nint)init);
    Console.WriteLine($"Loaded {path}");
    if (!Path.GetFullPath(path).StartsWith(AppContext.BaseDirectory, StringComparison.Ordinal))
    {
        throw new InvalidOperationException($"libusb was not loaded from the application folder {AppContext.BaseDirectory}.");
    }

    var version = getVersion();
    nint context;
    var result = init(&context);
    if (result != 0)
    {
        throw new InvalidOperationException($"libusb_init returned {result}.");
    }

    nint* devices;
    var count = getDeviceList(context, &devices);
    if (count < 0)
    {
        throw new InvalidOperationException($"libusb_get_device_list returned {count}.");
    }

    freeDeviceList(devices, 1);
    exit(context);
    Console.WriteLine($"{RuntimeInformation.RuntimeIdentifier}: libusb {version[0]}.{version[1]}.{version[2]} initialized and listed {count} devices");
}

static unsafe string GetLibraryPath(nint library, nint export)
{
    if (OperatingSystem.IsWindows())
    {
        var buffer = stackalloc char[1024];
        var length = GetModuleFileNameW(library, buffer, 1024);
        return new string(buffer, 0, (int)length);
    }

    var info = stackalloc nint[4];
    if (dladdr(export, info) == 0)
    {
        throw new InvalidOperationException("dladdr could not resolve the libusb library path.");
    }

    return Marshal.PtrToStringUTF8(info[0])!;
}

[DllImport("kernel32")]
static extern unsafe uint GetModuleFileNameW(nint module, char* fileName, uint size);

[DllImport("libc")]
static extern unsafe int dladdr(nint address, nint* info);
