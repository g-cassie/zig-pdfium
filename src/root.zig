//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub var c_pdfium: ?std.DynLib = null;

pub const FPDFDocument = *anyopaque;

pub var FPDF_LoadDocument: *const fn ([*c]const u8, [*c]u8) callconv(.C) ?FPDFDocument = undefined;
pub var FPDF_InitLibrary: *const fn () callconv(.C) void = undefined;
pub var FPDF_GetPageCount: *const fn (FPDFDocument) callconv(.C) c_int = undefined;
pub var FPDF_GetLastError: *const fn () callconv(.C) c_int = undefined;

pub fn bindPdfium() !void {
    c_pdfium = try std.DynLib.open("./vendor/pdfium-mac-arm64/lib/libpdfium.dylib");
    FPDF_InitLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_InitLibrary), "FPDF_InitLibrary").?;
    FPDF_LoadDocument = c_pdfium.?.lookup(@TypeOf(FPDF_LoadDocument), "FPDF_LoadDocument").?;
    FPDF_GetPageCount = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageCount), "FPDF_GetPageCount").?;
    FPDF_GetLastError = c_pdfium.?.lookup(@TypeOf(FPDF_GetLastError), "FPDF_GetLastError").?;
}

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
