const assert = std.debug.assert;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) @panic("Memory leak detected!");
    }
    const allocator = gpa.allocator();
    // realpathAlloc resolves all symbolic links and normalizes the path by removing any
    // "." and ".." components. It returns the absolute canonical path.
    const normalized_path = try std.fs.cwd().realpathAlloc(allocator, "./test/text-test.pdf");
    defer allocator.free(normalized_path);

    // Convert to C-compatible string (UTF-8, null-terminated)
    const c_path = try allocator.dupeZ(u8, normalized_path);
    defer allocator.free(c_path);
    std.debug.print("Normalized path: {s}\n", .{c_path});

    try lib.bindPdfium();
    lib.FPDF_InitLibrary();
    const pdf = lib.FPDF_LoadDocument(c_path, null) orelse {
        std.debug.print("LoadDocument failed with error code: {?}", .{lib.FPDF_GetLastError()});
        return;
    };
    const page_count = lib.FPDF_GetPageCount(pdf);

    std.debug.print("Page count: {}\n", .{page_count});

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
