const std = @import("std");
const pdfium = @import("../root.zig");
const testing = std.testing;

// Renders a page to a zig allocated buffer
pub fn renderPage(a: std.mem.Allocator, page: *pdfium.Page, format: pdfium.BitmapFormat, flags: pdfium.BitmapRenderFlags, scale: f64) ![]u8 {
    const width: c_int = @intFromFloat(@round(page.getWidth() * scale));
    const height: c_int = @intFromFloat(@round(page.getHeight() * scale));

    const bytes_per_pixel: c_int = switch (format) {
        .unknown => return error.UnsupportedFormat,
        .gray => 1,
        .bgr => 3,
        .bgrx => 4,
        .bgra => 4,
        .bgra_premul => 4,
    };
    const stride: c_int = width * bytes_per_pixel;

    const buffer = try a.alloc(u8, @intCast(height * stride));
    const bitmap = pdfium.Bitmap.initEx(width, height, format, buffer, stride) catch return error.OutOfMemory;
    defer bitmap.deinit();

    // fill the background with white
    try bitmap.fillRect(0, 0, width, height, 0xFFFFFFFF);
    bitmap.renderPage(page, 0, 0, width, height, 0, flags);

    return buffer;
}

test "renderPage" {
    const zigimg = @import("zigimg");
    const scale = 0.25;
    const test_pdf = try pdfium.Document.load("test/test.pdf");
    defer test_pdf.deinit();
    const page = test_pdf.loadPage(0) catch return;
    defer page.deinit();

    const width = @as(usize, @intFromFloat(@round(page.getWidth() * scale)));
    const height = @as(usize, @intFromFloat(@round(page.getHeight() * scale)));
    const buffer = try renderPage(testing.allocator, page, .bgra, .{}, scale);
    defer testing.allocator.free(buffer);

    var image = try zigimg.ImageUnmanaged.fromRawPixelsOwned(width, height, buffer, .bgra32);

    // Convert from BGRA to RGBA
    const rgba_pixels = try zigimg.PixelFormatConverter.convert(testing.allocator, &image.pixels, .rgba32);
    defer rgba_pixels.deinit(testing.allocator);

    var rgba_image = zigimg.ImageUnmanaged{
        .width = width,
        .height = height,
        .pixels = rgba_pixels,
    };

    const generated_path = "zig-out/tmp_test_pg0.png";
    try rgba_image.writeToFilePath(testing.allocator, generated_path, .{ .png = .{} });

    // Read both files into memory
    const expected = try std.fs.cwd().readFileAlloc(testing.allocator, "test/test_pg0.png", std.math.maxInt(usize));
    defer testing.allocator.free(expected);

    const generated = try std.fs.cwd().readFileAlloc(testing.allocator, generated_path, std.math.maxInt(usize));
    defer testing.allocator.free(generated);

    try testing.expectEqualSlices(u8, expected, generated);
}
