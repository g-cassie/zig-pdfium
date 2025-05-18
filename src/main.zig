const assert = std.debug.assert;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("Memory leak detected!");
    }

    try lib.bindPdfium();
    lib.FPDF_InitLibrary();
    const pdf = lib.FPDF_LoadDocument("./test/text-test.pdf", null) orelse {
        std.debug.print("LoadDocument failed with error code: {?}", .{lib.FPDF_GetLastError()});
        return;
    };
    const page_count = lib.FPDF_GetPageCount(pdf);

    const page = lib.FPDF_LoadPage(pdf, 0);
    defer lib.FPDF_ClosePage(page);

    const bitmap = lib.FPDFBitmap_Create(100, 100, 1);
    defer lib.FPDFBitmap_Destroy(bitmap);

    var flags: c_int = 0;
    flags |= lib.FPDF_GRAYSCALE;

    lib.FPDF_RenderPageBitmap(bitmap, page, 0, 0, 100, 100, 0, 0);

    std.debug.print("Page count: {}\n", .{page_count});
    // Create file to write bitmap data
    const bitmap_file = try std.fs.cwd().createFile("output.bmp", .{});
    defer bitmap_file.close();

    // Get bitmap buffer pointer and stride
    const buffer: [*]u8 = @ptrCast(lib.FPDFBitmap_GetBuffer(bitmap).?);
    const stride: usize = @intCast(lib.FPDFBitmap_GetStride(bitmap));

    // Write bitmap data
    const writer = bitmap_file.writer();
    // Write BMP header
    // File header (14 bytes)
    try writer.writeAll(&[_]u8{ 0x42, 0x4D }); // BM signature

    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, 14 + 40 + (100 * 100), .little); // File size
    try writer.writeAll(&bytes);

    std.mem.writeInt(u16, bytes[0..2], 0, .little); // Reserved
    try writer.writeAll(bytes[0..2]);
    std.mem.writeInt(u16, bytes[0..2], 0, .little); // Reserved
    try writer.writeAll(bytes[0..2]);

    std.mem.writeInt(u32, &bytes, 14 + 40, .little); // Offset to pixel data
    try writer.writeAll(&bytes);

    // Info header (40 bytes)
    std.mem.writeInt(u32, &bytes, 40, .little); // Size of info header
    try writer.writeAll(&bytes);
    std.mem.writeInt(i32, @alignCast(@ptrCast(&bytes)), 100, .little); // Width
    try writer.writeAll(&bytes);
    std.mem.writeInt(i32, @alignCast(@ptrCast(&bytes)), -100, .little); // Height (negative for top-down)
    try writer.writeAll(&bytes);
    std.mem.writeInt(u16, bytes[0..2], 1, .little); // Planes
    try writer.writeAll(bytes[0..2]);
    std.mem.writeInt(u16, bytes[0..2], 8, .little); // Bits per pixel
    try writer.writeAll(bytes[0..2]);
    std.mem.writeInt(u32, &bytes, 0, .little); // Compression
    try writer.writeAll(&bytes);
    std.mem.writeInt(u32, &bytes, 0, .little); // Image size
    try writer.writeAll(&bytes);
    std.mem.writeInt(i32, @alignCast(@ptrCast(&bytes)), 0, .little); // X pixels per meter
    try writer.writeAll(&bytes);
    std.mem.writeInt(i32, @alignCast(@ptrCast(&bytes)), 0, .little); // Y pixels per meter
    try writer.writeAll(&bytes);
    std.mem.writeInt(u32, &bytes, 256, .little); // Colors used
    try writer.writeAll(&bytes);
    std.mem.writeInt(u32, &bytes, 256, .little); // Important colors
    try writer.writeAll(&bytes);

    // Write grayscale palette
    {
        var i: u32 = 0;
        while (i < 256) : (i += 1) {
            std.mem.writeInt(u32, &bytes, i | (i << 8) | (i << 16), .little);
            try writer.writeAll(&bytes);
        }
    }
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const start = i * stride;
        const end = start + stride;
        try writer.writeAll(buffer[start..end]);
    }

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig_pdfium_lib");
