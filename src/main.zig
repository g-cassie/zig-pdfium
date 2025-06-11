const std = @import("std");
const pdfium = @import("root.zig");
const log = std.log.scoped(.pdfium);

pub fn main() !void {
    // Initialize the general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Hardcoded paths for testing
    const input_path = "test/test.pdf";
    const output_path1 = "test/first.pdf";
    const output_path2 = "test/second.pdf";

    // Initialize PDFium
    try pdfium.bindPdfium("vendor/pdfium-mac-arm64/lib/libpdfium.dylib");
    pdfium.initLibrary();
    defer pdfium.destroyLibrary();

    // Load the input PDF
    const test_pdf = try pdfium.Document.load(input_path);
    defer test_pdf.deinit();

    // Create first PDF with first two pages
    const first_pdf = try pdfium.Document.createNew();
    defer first_pdf.deinit();
    try pdfium.importPagesByIndex(first_pdf, test_pdf, &[_]usize{ 0, 1 }, 0);

    // Create second PDF with last three pages
    const second_pdf = try pdfium.Document.createNew();
    defer second_pdf.deinit();
    try pdfium.importPagesByIndex(second_pdf, test_pdf, &[_]usize{ 2, 3, 4 }, 0);

    // Save first PDF
    var first_file = try std.fs.cwd().createFile(output_path1, .{});
    defer first_file.close();
    const first_write = pdfium.FileWrite{
        .version = 1,
        .write_block = struct {
            fn write(self: *pdfium.FileWrite, data: [*]const u8, size: usize) callconv(.C) c_int {
                const file = @as(*std.fs.File, @ptrCast(@alignCast(@constCast(self))));
                const write_result = file.write(data[0..size]) catch |err| {
                    log.err("Failed to write PDF data: {}", .{err});
                    return 0;
                };
                log.debug("Wrote {d} bytes to PDF", .{write_result});
                return 1;
            }
        }.write,
    };
    log.debug("Starting PDF save...", .{});
    try first_pdf.saveAsCopy(@constCast(&first_write), .none);
    log.debug("PDF save completed", .{});

    // Verify file was written
    const stat = try first_file.stat();
    if (stat.size == 0) {
        return error.FileWriteFailed;
    }

    // Save second PDF
    var second_file = try std.fs.cwd().createFile(output_path2, .{});
    defer second_file.close();
    const second_write = pdfium.FileWrite{
        .version = 1,
        .write_block = struct {
            fn write(self: *pdfium.FileWrite, data: [*]const u8, size: usize) callconv(.C) c_int {
                const file = @as(*std.fs.File, @ptrCast(@alignCast(@constCast(self))));
                _ = file.write(data[0..size]) catch return 0;
                return 1;
            }
        }.write,
    };
    try second_pdf.saveAsCopy(@constCast(&second_write), .none);

    // Verify the new PDFs have correct number of pages
    const first_verify = try pdfium.Document.load(output_path1);
    defer first_verify.deinit();
    if (first_verify.getPageCount() != 2) {
        return error.InvalidPageCount;
    }

    const second_verify = try pdfium.Document.load(output_path2);
    defer second_verify.deinit();
    if (second_verify.getPageCount() != 3) {
        return error.InvalidPageCount;
    }

    std.debug.print("Successfully split PDF into two files:\n{s} (2 pages)\n{s} (3 pages)\n", .{ output_path1, output_path2 });
}
