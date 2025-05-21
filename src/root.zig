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
pub var FPDF_GetPageWidthF: *@TypeOf(c.FPDF_GetPageWidthF) = undefined;
pub var FPDF_GetPageHeightF: *@TypeOf(c.FPDF_GetPageHeightF) = undefined;

// fpdf_text.h
pub var FPDFText_LoadPage: *@TypeOf(c.FPDFText_LoadPage) = undefined;
pub var FPDFText_ClosePage: *@TypeOf(c.FPDFText_ClosePage) = undefined;
pub var FPDFText_CountRects: *@TypeOf(c.FPDFText_CountRects) = undefined;
pub var FPDFText_GetRect: *@TypeOf(c.FPDFText_GetRect) = undefined;

pub fn bindPdfium(path: []const u8) !void {
    c_pdfium = try std.DynLib.open(path);

    // Top Level Methods
    FPDF_InitLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_InitLibrary), "FPDF_InitLibrary").?;
    FPDF_GetLastError = c_pdfium.?.lookup(@TypeOf(FPDF_GetLastError), "FPDF_GetLastError").?;

    // FPDFDocument methods
    FPDF_LoadDocument = c_pdfium.?.lookup(@TypeOf(FPDF_LoadDocument), "FPDF_LoadDocument").?;
    FPDF_GetPageCount = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageCount), "FPDF_GetPageCount").?;

    FPDF_RenderPageBitmap = c_pdfium.?.lookup(@TypeOf(FPDF_RenderPageBitmap), "FPDF_RenderPageBitmap").?;

    // FPDFBitmap methods
    FPDFBitmap_Create = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_Create), "FPDFBitmap_Create").?;
    FPDFBitmap_Destroy = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_Destroy), "FPDFBitmap_Destroy").?;
    FPDFBitmap_GetBuffer = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_GetBuffer), "FPDFBitmap_GetBuffer").?;
    FPDFBitmap_GetStride = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_GetStride), "FPDFBitmap_GetStride").?;
    FPDFBitmap_FillRect = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_FillRect), "FPDFBitmap_FillRect").?;
    FPDFBitmap_CreateEx = c_pdfium.?.lookup(@TypeOf(FPDFBitmap_CreateEx), "FPDFBitmap_CreateEx").?;

    // FPDFPage methods
    FPDF_LoadPage = c_pdfium.?.lookup(@TypeOf(FPDF_LoadPage), "FPDF_LoadPage").?;
    FPDF_ClosePage = c_pdfium.?.lookup(@TypeOf(FPDF_ClosePage), "FPDF_ClosePage").?;
    FPDF_CloseDocument = c_pdfium.?.lookup(@TypeOf(FPDF_CloseDocument), "FPDF_CloseDocument").?;
    FPDF_GetPageWidthF = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageWidthF), "FPDF_GetPageWidthF").?;
    FPDF_GetPageHeightF = c_pdfium.?.lookup(@TypeOf(FPDF_GetPageHeightF), "FPDF_GetPageHeightF").?;

    // fpdf_text.h
    FPDFText_LoadPage = c_pdfium.?.lookup(@TypeOf(FPDFText_LoadPage), "FPDFText_LoadPage").?;
    FPDFText_ClosePage = c_pdfium.?.lookup(@TypeOf(FPDFText_ClosePage), "FPDFText_ClosePage").?;
    FPDFText_CountRects = c_pdfium.?.lookup(@TypeOf(FPDFText_CountRects), "FPDFText_CountRects").?;
    FPDFText_GetRect = c_pdfium.?.lookup(@TypeOf(FPDFText_GetRect), "FPDFText_GetRect").?;
}

const Error = error{
    Unknown,
    File,
    Format,
    Password,
    Security,
    Page,
    XFALoad,
    XFALayout,
};

pub fn initLibrary() void {
    FPDF_InitLibrary();
}

pub fn getLastError() ?Error {
    const err = FPDF_GetLastError();
    switch (err) {
        c.FPDF_ERR_SUCCESS => return null,
        c.FPDF_ERR_UNKNOWN => return error.Unknown,
        c.FPDF_ERR_FILE => return error.File,
        c.FPDF_ERR_FORMAT => return error.Format,
        c.FPDF_ERR_PASSWORD => return error.Password,
        c.FPDF_ERR_SECURITY => return error.Security,
        c.FPDF_ERR_PAGE => return error.Page,
        else => {},
    }
    // TODO need some comptime magic to handle this
    // if (c.PDF_ENABLE_XFA) {
    //     switch (err) {
    //         c.FPDF_ERR_XFALOAD => return error.XFALoad,
    //         c.FPDF_ERR_XFALAYOUT => return error.XFALayout,
    //         else => {},
    //     }
    // }
    unreachable;
}

pub const Document = struct {
    fpdf_document: c.FPDF_DOCUMENT,

    pub fn load(path: []const u8) !Document {
        const fpdf_document = FPDF_LoadDocument(path.ptr, null);
        if (fpdf_document == null) {
            return getLastError().?;
        }
        return Document{ .fpdf_document = fpdf_document.? };
    }

    pub fn deinit(self: *Document) void {
        FPDF_CloseDocument(self.fpdf_document);
    }

    pub fn getPageCount(self: *Document) c_int {
        return FPDF_GetPageCount(self.fpdf_document);
    }

    pub fn loadPage(self: *Document, index: c_int) !Page {
        const fpdf_page = FPDF_LoadPage(self.fpdf_document, index);
        if (fpdf_page == null) {
            return error.LoadFailed;
        }
        return Page{ .fpdf_page = fpdf_page.? };
    }
};

pub const Page = struct {
    fpdf_page: c.FPDF_PAGE,

    pub fn deinit(self: *Page) void {
        FPDF_ClosePage(self.fpdf_page);
    }

    pub fn getWidth(self: *Page) f64 {
        return FPDF_GetPageWidthF(self.fpdf_page);
    }

    pub fn getHeight(self: *Page) f64 {
        return FPDF_GetPageHeightF(self.fpdf_page);
    }

    pub fn loadTextPage(self: *Page) !TextPage {
        const fpdf_text_page = FPDFText_LoadPage(self.fpdf_page);
        if (fpdf_text_page == null) {
            return error.LoadFailed;
        }
        return TextPage{ .fpdf_text_page = fpdf_text_page.? };
    }
};

const BitmapFormat = enum(c_int) {
    unknown = c.FPDFBitmap_Unknown,
    gray = c.FPDFBitmap_Gray,
    bgr = c.FPDFBitmap_BGR,
    bgrx = c.FPDFBitmap_BGRx,
    bgra = c.FPDFBitmap_BGRA,
    bgra_premul = c.FPDFBitmap_BGRA_Premul,
};

pub const Bitmap = struct {
    fpdf_bitmap: c.FPDF_BITMAP,

    pub fn initEx(width: c_int, height: c_int, format: BitmapFormat, buffer: []u8, stride: c_int) !Bitmap {
        const fpdf_bitmap = FPDFBitmap_CreateEx(width, height, @intFromEnum(format), buffer.ptr, stride);
        if (fpdf_bitmap == null) {
            return error.ParameterError;
        }
        return Bitmap{ .fpdf_bitmap = fpdf_bitmap.? };
    }

    pub fn fillRect(self: *Bitmap, x: c_int, y: c_int, width: c_int, height: c_int, color: u32) !void {
        const success = FPDFBitmap_FillRect(self.fpdf_bitmap, x, y, width, height, color);
        if (success != 1) {
            return error.FillFailed;
        }
    }

    pub fn renderPage(
        self: *Bitmap,
        page: *Page,
        x: c_int,
        y: c_int,
        width: c_int,
        height: c_int,
        rotate: c_int,
        flags: c_int,
    ) void {
        FPDF_RenderPageBitmap(self.fpdf_bitmap, page.fpdf_page, x, y, width, height, rotate, flags);
    }

    pub fn deinit(self: *Bitmap) void {
        FPDFBitmap_Destroy(self.fpdf_bitmap);
    }
};

pub const TextPageRect = struct {
    left: f64,
    top: f64,
    right: f64,
    bottom: f64,
};

pub const TextPage = struct {
    fpdf_text_page: c.FPDF_TEXTPAGE,

    pub fn deinit(self: *TextPage) void {
        FPDFText_ClosePage(self.fpdf_text_page);
    }

    pub fn getRect(self: *TextPage, index: usize) !TextPageRect {
        var r: TextPageRect = .{
            .left = std.math.floatMax(f64),
            .top = std.math.floatMax(f64),
            .right = std.math.floatMin(f64),
            .bottom = std.math.floatMin(f64),
        };
        const success: c_int = FPDFText_GetRect(self.fpdf_text_page, @intCast(index), &r.left, &r.top, &r.right, &r.bottom);
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
        const result: c_int = FPDFText_CountRects(self.fpdf_text_page, @intCast(start), c_count);
        if (result < 0) {
            return error.InvalidStartIndex;
        }
        return @intCast(result);
    }
};
