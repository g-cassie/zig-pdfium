//! Dynamic library loading, with a Windows implementation of our own.
//!
//! Zig 0.16 dropped Windows support from `std.DynLib`: its `InnerType` switch
//! now falls through to `@compileError("unsupported platform")` for anything
//! that is not Linux or a Darwin/BSD `dlopen` target. The `WindowsDynLib` that
//! used to be there went away along with the `LoadLibraryW`, `LoadLibraryExW`,
//! `GetProcAddress` and `FreeLibrary` bindings in `std.os.windows.kernel32`.
//!
//! `DynLib` below is `std.DynLib` everywhere it still exists and a port of
//! 0.15.2's `WindowsDynLib` on Windows, so `bindPdfium` keeps one shape. The
//! kernel32 signatures are 0.15.2's, which match MSDN.

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

pub const DynLib = if (builtin.os.tag == .windows) WindowsDynLib else std.DynLib;

pub const WindowsDynLib = struct {
    dll: windows.HMODULE,

    pub const Error = error{
        FileNotFound,
        BadPathName,
        NameTooLong,
    } || std.posix.UnexpectedError;

    /// Long enough for any real install path. The full NT limit
    /// (`windows.PATH_MAX_WIDE`, 32767) would be a 64 KiB stack frame, which is
    /// not worth it for a path that is either next to the executable or a
    /// bare DLL name.
    const path_buf_len = 4096;

    /// Trusts the file. A malicious library will be able to execute arbitrary
    /// code.
    ///
    /// A `path` containing a separator is resolved as a path (relative ones
    /// against the current directory); a bare name goes through the standard
    /// DLL search order, which starts at the executable's own directory.
    pub fn open(path: []const u8) Error!WindowsDynLib {
        var buf: [path_buf_len]u16 = undefined;
        const len = try windows.wtf8ToWtf16Le(&buf, path);
        if (len >= buf.len) return error.NameTooLong;
        buf[len] = 0;

        // LoadLibraryExW only accepts backslashes when it treats the argument
        // as a path. `std.fs.path` hands us forward slashes often enough that
        // it is worth normalizing rather than failing.
        for (buf[0..len]) |*wc| {
            if (wc.* == '/') wc.* = '\\';
        }

        return openW(buf[0..len :0]);
    }

    pub fn openZ(path_c: [*:0]const u8) Error!WindowsDynLib {
        return open(std.mem.span(path_c));
    }

    pub fn openW(path_w: [*:0]const u16) Error!WindowsDynLib {
        return .{
            .dll = LoadLibraryExW(path_w, null, 0) orelse switch (windows.GetLastError()) {
                .FILE_NOT_FOUND, .PATH_NOT_FOUND, .MOD_NOT_FOUND => return error.FileNotFound,
                .INVALID_NAME, .BAD_PATHNAME => return error.BadPathName,
                .FILENAME_EXCED_RANGE => return error.NameTooLong,
                else => |err| return windows.unexpectedError(err),
            },
        };
    }

    pub fn close(self: *WindowsDynLib) void {
        _ = FreeLibrary(self.dll);
        self.* = undefined;
    }

    pub fn lookup(self: *WindowsDynLib, comptime T: type, name: [:0]const u8) ?T {
        if (GetProcAddress(self.dll, name.ptr)) |addr| {
            return @ptrCast(@alignCast(addr));
        } else {
            return null;
        }
    }
};

extern "kernel32" fn LoadLibraryExW(
    lpLibFileName: windows.LPCWSTR,
    hFile: ?windows.HANDLE,
    dwFlags: windows.DWORD,
) callconv(.winapi) ?windows.HMODULE;

extern "kernel32" fn GetProcAddress(
    hModule: windows.HMODULE,
    lpProcName: windows.LPCSTR,
) callconv(.winapi) ?windows.FARPROC;

extern "kernel32" fn FreeLibrary(
    hLibModule: windows.HMODULE,
) callconv(.winapi) windows.BOOL;
