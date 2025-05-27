//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("fpdfview.h");
    @cInclude("fpdf_text.h");
});
const testing = std.testing;
const assert = std.debug.assert;
const panic = std.debug.panic;

var DID_INIT: bool = false;
var IS_BOUND: bool = false;

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
    defer IS_BOUND = true;
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
    Success,
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
    assert(IS_BOUND);
    FPDF_InitLibrary();
    DID_INIT = true;
}

pub fn getLastError() Error {
    const err = FPDF_GetLastError();
    switch (err) {
        c.FPDF_ERR_SUCCESS => return error.Success,
        c.FPDF_ERR_UNKNOWN => return error.Unknown,
        c.FPDF_ERR_FILE => return error.File,
        c.FPDF_ERR_FORMAT => return error.Format,
        c.FPDF_ERR_PASSWORD => return error.Password,
        c.FPDF_ERR_SECURITY => return error.Security,
        c.FPDF_ERR_PAGE => return error.Page,
        else => {
            if (@hasDecl(c, "PDF_ENABLE_XFA")) {
                if (err == c.FPDF_ERR_XFALOAD) {
                    return error.XFALoad;
                } else if (err == c.FPDF_ERR_XFALAYOUT) {
                    return error.XFALayout;
                }
            }
        },
    }
    unreachable;
}

fn assertLoaded() void {
    if (builtin.mode == .Debug and !DID_INIT) {
        panic("You must call initLibrary() before using the PDFium library or you will get segfaults", .{});
    }
}

pub const Document = opaque {
    pub fn load(path: [:0]const u8) !*Document {
        assertLoaded();
        // TODO: null terminate path
        if (FPDF_LoadDocument(path.ptr, null)) |doc| {
            return @ptrCast(doc);
        } else {
            return getLastError();
        }
    }

    pub fn deinit(self: *Document) void {
        FPDF_CloseDocument(@ptrCast(self));
    }

    pub fn getPageCount(self: *Document) usize {
        return @intCast(FPDF_GetPageCount(@ptrCast(self)));
    }

    pub fn loadPage(self: *Document, index: usize) !*Page {
        if (FPDF_LoadPage(@ptrCast(self), @intCast(index))) |page| {
            return @ptrCast(page);
        } else {
            return error.LoadFailed;
        }
    }
};

pub const Page = opaque {
    pub fn deinit(self: *Page) void {
        FPDF_ClosePage(@ptrCast(self));
    }

    pub fn getWidth(self: *Page) f64 {
        return FPDF_GetPageWidthF(@ptrCast(self));
    }

    pub fn getHeight(self: *Page) f64 {
        return FPDF_GetPageHeightF(@ptrCast(self));
    }

    pub fn loadTextPage(self: *Page) !*TextPage {
        if (FPDFText_LoadPage(@ptrCast(self))) |text_page| {
            return @ptrCast(text_page);
        } else {
            return error.LoadFailed;
        }
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

pub const Bitmap = opaque {
    pub fn initEx(width: c_int, height: c_int, format: BitmapFormat, buffer: []u8, stride: c_int) !*Bitmap {
        assertLoaded();
        const fpdf_bitmap = FPDFBitmap_CreateEx(width, height, @intFromEnum(format), buffer.ptr, stride);
        if (fpdf_bitmap == null) {
            return error.ParameterError;
        }
        return @ptrCast(fpdf_bitmap.?);
    }

    pub fn fillRect(self: *Bitmap, x: c_int, y: c_int, width: c_int, height: c_int, color: u32) !void {
        const success = FPDFBitmap_FillRect(@ptrCast(self), x, y, width, height, color);
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
        FPDF_RenderPageBitmap(@ptrCast(self), @ptrCast(page), x, y, width, height, rotate, flags);
    }

    pub fn deinit(self: *Bitmap) void {
        FPDFBitmap_Destroy(@ptrCast(self));
    }
};

pub const TextPageRect = struct {
    left: f64,
    top: f64,
    right: f64,
    bottom: f64,
};

pub const TextPage = opaque {
    pub fn deinit(self: *TextPage) void {
        FPDFText_ClosePage(@ptrCast(self));
    }

    pub fn getRect(self: *TextPage, index: usize) !TextPageRect {
        var r: TextPageRect = .{
            .left = std.math.floatMax(f64),
            .top = std.math.floatMax(f64),
            .right = std.math.floatMin(f64),
            .bottom = std.math.floatMin(f64),
        };
        const success: c_int = FPDFText_GetRect(@ptrCast(self), @intCast(index), &r.left, &r.top, &r.right, &r.bottom);
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
        const result: c_int = FPDFText_CountRects(@ptrCast(self), @intCast(start), c_count);
        if (result < 0) {
            return error.InvalidStartIndex;
        }
        return @intCast(result);
    }
};
