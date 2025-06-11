const lib = @import("../root.zig");
const std = @import("std");
const Document = lib.Document;
const log = lib.log;
const testing = std.testing;

const FileWriteWrapper = struct {
    write: lib.FileWrite,
    file: std.fs.File,
};

fn writeBlock(self: *lib.FileWrite, data: [*c]const u8, size: c_long) callconv(.C) c_int {
    const wrapper: *FileWriteWrapper = @fieldParentPtr("write", self);
    const file = wrapper.file;
    file.writeAll(data[0..@intCast(size)]) catch |err| {
        log.err("Failed to write PDF data: {}", .{err});
        return 0;
    };
    log.debug("Wrote {d} bytes to PDF", .{size});
    return 1;
}

pub fn saveToFile(pdf: *Document, file: std.fs.File) !void {
    const wrapper = FileWriteWrapper{
        .write = .{
            .version = 1,
            .write_block = &writeBlock,
        },
        .file = file,
    };
    try pdf.saveAsCopy(@constCast(&wrapper.write), .none);
}

test "saveToFile - can extract pages to a pdf and save" {
    try lib.bindPdfium("vendor/pdfium-mac-arm64/lib/libpdfium.dylib");
    lib.initLibrary();
    defer lib.destroyLibrary();
    const src = try Document.load("test/test.pdf");
    defer src.deinit();

    // Create PDF with first two pages
    const pdf = try Document.createNew();
    defer pdf.deinit();
    try lib.importPagesByIndex(pdf, src, &[_]usize{ 0, 1 }, 0);

    // Save PDF
    var file = try std.fs.cwd().createFile("zig-out/first.pdf", .{});
    defer file.close();
    try saveToFile(pdf, file);

    // Verify file was written
    const stat = try file.stat();
    try testing.expect(stat.size > 0);

    // Verify PDF has correct number of pages
    const verify = try Document.load("zig-out/first.pdf");
    defer verify.deinit();
    try testing.expectEqual(@as(usize, 2), verify.getPageCount());
}
