//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const c = @cImport({
    @cInclude("fpdfview.h");
    @cInclude("fpdf_text.h");
});
const testing = std.testing;

pub var c_pdfium: ?std.DynLib = null;
pub const FPDF_GRAYSCALE = c.FPDF_GRAYSCALE;
pub const FPDFBitmap_BGRA = c.FPDFBitmap_BGRA;
// pub var FPDF_LoadDocument: *const fn ([*c]const u8, [*c]u8) callconv(.C) c.FPDF_DOCUMENT = undefined;
pub var FPDF_LoadDocument: *@TypeOf(c.FPDF_LoadDocument) = undefined;
pub var FPDF_InitLibrary: *@TypeOf(c.FPDF_InitLibrary) = undefined;
pub var FPDF_GetPageCount: *@TypeOf(c.FPDF_GetPageCount) = undefined;
pub var FPDF_GetLastError: *@TypeOf(c.FPDF_GetLastError) = undefined;
pub var FPDF_RenderPageBitmap: *@TypeOf(c.FPDF_RenderPageBitmap) = undefined;
pub var FPDFBitmap_Create: *@TypeOf(c.FPDFBitmap_Create) = undefined;
pub var FPDFBitmap_Destroy: *@TypeOf(c.FPDFBitmap_Destroy) = undefined;
pub var FPDFBitmap_CreateEx: *@TypeOf(c.FPDFBitmap_CreateEx) = undefined;
pub var FPDFBitmap_GetBuffer: *@TypeOf(c.FPDFBitmap_GetBuffer) = undefined;
pub var FPDFBitmap_GetStride: *@TypeOf(c.FPDFBitmap_GetStride) = undefined;
pub var FPDFBitmap_FillRect: *@TypeOf(c.FPDFBitmap_FillRect) = undefined;

pub var FPDF_LoadPage: *@TypeOf(c.FPDF_LoadPage) = undefined;
pub var FPDF_ClosePage: *@TypeOf(c.FPDF_ClosePage) = undefined;
pub var FPDF_CloseDocument: *@TypeOf(c.FPDF_CloseDocument) = undefined;
pub var FPDF_GetPageWidth: *@TypeOf(c.FPDF_GetPageWidth) = undefined;
pub var FPDF_GetPageHeight: *@TypeOf(c.FPDF_GetPageHeight) = undefined;

// fpdf_text.h
pub var FPDFText_LoadPage: *@TypeOf(c.FPDFText_LoadPage) = undefined;
pub var FPDFText_ClosePage: *@TypeOf(c.FPDFText_ClosePage) = undefined;
pub var FPDFText_CountRects: *@TypeOf(c.FPDFText_CountRects) = undefined;
pub var FPDFText_GetRect: *@TypeOf(c.FPDFText_GetRect) = undefined;

pub fn bindPdfium(path: []const u8) !void {
    c_pdfium = try std.DynLib.open(path);

    FPDF_InitLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_InitLibrary), "FPDF_InitLibrary").?;
    FPDF_LoadDocument = c_pdfium.?.lookup(@TypeOf(FPDF_LoadDocument), "FPDF_LoadDocument").?;
    FPDF_GetPageCount = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageCount), "FPDF_GetPageCount").?;
    FPDF_GetLastError = c_pdfium.?.lookup(@TypeOf(FPDF_GetLastError), "FPDF_GetLastError").?;
    FPDF_RenderPageBitmap = c_pdfium.?.lookup(@TypeOf(FPDF_RenderPageBitmap), "FPDF_RenderPageBitmap").?;

    FPDFBitmap_Create = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_Create), "FPDFBitmap_Create").?;
    FPDFBitmap_Destroy = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_Destroy), "FPDFBitmap_Destroy").?;
    FPDFBitmap_GetBuffer = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_GetBuffer), "FPDFBitmap_GetBuffer").?;
    FPDFBitmap_GetStride = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_GetStride), "FPDFBitmap_GetStride").?;
    FPDFBitmap_FillRect = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_FillRect), "FPDFBitmap_FillRect").?;
    FPDFBitmap_CreateEx = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_CreateEx), "FPDFBitmap_CreateEx").?;
    FPDF_LoadPage = c_pdfium.?.lookup(@TypeOf(FPDF_LoadPage), "FPDF_LoadPage").?;
    FPDF_ClosePage = c_pdfium.?.lookup(@TypeOf(FPDF_ClosePage), "FPDF_ClosePage").?;
    FPDF_CloseDocument = c_pdfium.?.lookup(@TypeOf(FPDF_CloseDocument), "FPDF_CloseDocument").?;
    FPDF_GetPageWidth = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageWidth), "FPDF_GetPageWidth").?;
    FPDF_GetPageHeight = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageHeight), "FPDF_GetPageHeight").?;

    // fpdf_text.h
    FPDFText_LoadPage = c_pdfium.?.lookup(@TypeOf(FPDFText_LoadPage), "FPDFText_LoadPage").?;
    FPDFText_ClosePage = c_pdfium.?.lookup(@TypeOf(FPDFText_ClosePage), "FPDFText_ClosePage").?;
    FPDFText_CountRects = c_pdfium.?.lookup(@TypeOf(FPDFText_CountRects), "FPDFText_CountRects").?;
    FPDFText_GetRect = c_pdfium.?.lookup(@TypeOf(FPDFText_GetRect), "FPDFText_GetRect").?;
}

pub const TextPageRect = struct {
    left: f64,
    top: f64,
    right: f64,
    bottom: f64,
};

pub const TextPage = struct {
    page: c.FPDF_TEXTPAGE,

    pub fn initFromPage(page: c.FPDF_PAGE) !TextPage {
        const text_page = FPDFText_LoadPage(page);
        if (text_page == null) {
            return error.LoadPageFailed;
        }
        return TextPage{ .page = text_page.? };
    }

    pub fn deinit(self: *TextPage) void {
        FPDFText_ClosePage(self.page);
    }

    pub fn getRect(self: *TextPage, index: usize) !TextPageRect {
        var r: TextPageRect = .{
            .left = std.math.floatMax(f64),
            .top = std.math.floatMax(f64),
            .right = std.math.floatMin(f64),
            .bottom = std.math.floatMin(f64),
        };
        const success: c_int = FPDFText_GetRect(self.page, @intCast(index), &r.left, &r.top, &r.right, &r.bottom);
        if (success != 1) {
            if (r.left == 0 and r.top == 0 and r.right == 0 and r.bottom == 0) {
                return error.IndexOutOfBounds;
            } else {
                return error.InvalidTextPage;
            }
        }
        return r;
    }

    pub fn countRects(self: *TextPage, start: usize, count: ?usize) !usize {
        const c_count: c_int = if (count) |x| @intCast(x) else -1;
        const result: c_int = FPDFText_CountRects(self.page, @intCast(start), c_count);
        if (result < 0) {
            return error.InvalidStartIndex;
        }
        return @intCast(result);
    }
};
