//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.pdfium);
const c = @cImport({
    @cInclude("fpdfview.h");
    @cInclude("fpdf_text.h");
    @cInclude("fpdf_doc.h");
    @cInclude("fpdf_annot.h");
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
pub var FPDF_DestroyLibrary: *@TypeOf(c.FPDF_DestroyLibrary) = undefined;
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

pub var FPDFPage_GetAnnotCount: *@TypeOf(c.FPDFPage_GetAnnotCount) = undefined;
pub var FPDFPage_GetAnnot: *@TypeOf(c.FPDFPage_GetAnnot) = undefined;
pub var FPDFPage_CloseAnnot: *@TypeOf(c.FPDFPage_CloseAnnot) = undefined;
pub var FPDFAnnot_GetSubtype: *@TypeOf(c.FPDFAnnot_GetSubtype) = undefined;
pub var FPDFAnnot_GetRect: *@TypeOf(c.FPDFAnnot_GetRect) = undefined;
pub var FPDFAnnot_GetLink: *@TypeOf(c.FPDFAnnot_GetLink) = undefined;
pub var FPDFLink_GetDest: *@TypeOf(c.FPDFLink_GetDest) = undefined;
pub var FPDFLink_GetAction: *@TypeOf(c.FPDFLink_GetAction) = undefined;
pub var FPDFLink_Enumerate: *@TypeOf(c.FPDFLink_Enumerate) = undefined;
pub var FPDFLink_GetAnnotRect: *@TypeOf(c.FPDFLink_GetAnnotRect) = undefined;
pub var FPDFDest_GetDestPageIndex: *@TypeOf(c.FPDFDest_GetDestPageIndex) = undefined;
pub var FPDFAction_GetDest: *@TypeOf(c.FPDFAction_GetDest) = undefined;

// Bookmark related APIs
pub var FPDFBookmark_GetFirstChild: *@TypeOf(c.FPDFBookmark_GetFirstChild) = undefined;
pub var FPDFBookmark_GetNextSibling: *@TypeOf(c.FPDFBookmark_GetNextSibling) = undefined;
pub var FPDFBookmark_GetTitle: *@TypeOf(c.FPDFBookmark_GetTitle) = undefined;
pub var FPDFBookmark_GetCount: *@TypeOf(c.FPDFBookmark_GetCount) = undefined;
pub var FPDFBookmark_Find: *@TypeOf(c.FPDFBookmark_Find) = undefined;
pub var FPDFBookmark_GetDest: *@TypeOf(c.FPDFBookmark_GetDest) = undefined;
pub var FPDFBookmark_GetAction: *@TypeOf(c.FPDFBookmark_GetAction) = undefined;

pub fn bindPdfium(path: []const u8) !void {
    defer IS_BOUND = true;
    c_pdfium = try std.DynLib.open(path);

    // Top Level Methods
    FPDF_InitLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_InitLibrary), "FPDF_InitLibrary").?;
    FPDF_DestroyLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_DestroyLibrary), "FPDF_DestroyLibrary").?;
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

    // Annotation and Link methods
    FPDFPage_GetAnnotCount = c_pdfium.?.lookup(@TypeOf(FPDFPage_GetAnnotCount), "FPDFPage_GetAnnotCount").?;
    FPDFPage_GetAnnot = c_pdfium.?.lookup(@TypeOf(FPDFPage_GetAnnot), "FPDFPage_GetAnnot").?;
    FPDFPage_CloseAnnot = c_pdfium.?.lookup(@TypeOf(FPDFPage_CloseAnnot), "FPDFPage_CloseAnnot").?;
    FPDFAnnot_GetSubtype = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetSubtype), "FPDFAnnot_GetSubtype").?;
    FPDFAnnot_GetRect = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetRect), "FPDFAnnot_GetRect").?;
    FPDFAnnot_GetLink = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetLink), "FPDFAnnot_GetLink").?;
    FPDFLink_GetDest = c_pdfium.?.lookup(@TypeOf(FPDFLink_GetDest), "FPDFLink_GetDest").?;
    FPDFLink_GetAction = c_pdfium.?.lookup(@TypeOf(FPDFLink_GetAction), "FPDFLink_GetAction").?;
    FPDFLink_Enumerate = c_pdfium.?.lookup(@TypeOf(FPDFLink_Enumerate), "FPDFLink_Enumerate").?;
    FPDFLink_GetAnnotRect = c_pdfium.?.lookup(@TypeOf(FPDFLink_GetAnnotRect), "FPDFLink_GetAnnotRect").?;
    FPDFDest_GetDestPageIndex = c_pdfium.?.lookup(@TypeOf(FPDFDest_GetDestPageIndex), "FPDFDest_GetDestPageIndex").?;
    FPDFAction_GetDest = c_pdfium.?.lookup(@TypeOf(FPDFAction_GetDest), "FPDFAction_GetDest").?;

    // Bookmark related APIs
    FPDFBookmark_GetFirstChild = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetFirstChild), "FPDFBookmark_GetFirstChild").?;
    FPDFBookmark_GetNextSibling = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetNextSibling), "FPDFBookmark_GetNextSibling").?;
    FPDFBookmark_GetTitle = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetTitle), "FPDFBookmark_GetTitle").?;
    FPDFBookmark_GetCount = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetCount), "FPDFBookmark_GetCount").?;
    FPDFBookmark_Find = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_Find), "FPDFBookmark_Find").?;
    FPDFBookmark_GetDest = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetDest), "FPDFBookmark_GetDest").?;
    FPDFBookmark_GetAction = c_pdfium.?.lookup(@TypeOf(FPDFBookmark_GetAction), "FPDFBookmark_GetAction").?;
}

pub const Error = error{
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
    assert(!DID_INIT);
    FPDF_InitLibrary();
    DID_INIT = true;
}

pub fn destroyLibrary() void {
    assert(IS_BOUND);
    if (DID_INIT) {
        FPDF_DestroyLibrary();
        DID_INIT = false;
    }
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

    pub fn getFirstBookmark(self: *Document) ?*Bookmark {
        if (FPDFBookmark_GetFirstChild(@ptrCast(self), null)) |bookmark| {
            return @ptrCast(bookmark);
        }
        return null;
    }
};

pub const Page = opaque {
    const LinkIterator = struct {
        index: c_int,
        page: *Page,

        pub fn next(self: *LinkIterator) ?*Link {
            var link: c.FPDF_LINK = null;
            if (FPDFLink_Enumerate(@ptrCast(self.page), &self.index, &link) > 0) {
                return @ptrCast(link);
            }
            return null;
        }
    };

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

    pub fn getAnnotationCount(self: *Page) usize {
        return @intCast(FPDFPage_GetAnnotCount(@ptrCast(self)));
    }

    pub fn getAnnotation(self: *Page, index: usize) !*Annotation {
        if (FPDFPage_GetAnnot(@ptrCast(self), @intCast(index))) |annot| {
            return @ptrCast(annot);
        }
        return error.GetAnnotationFailed;
    }

    pub fn linkIterator(self: *Page) LinkIterator {
        return LinkIterator{
            .index = 0,
            .page = self,
        };
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

const BitmapRenderFlags = packed struct {
    annot: bool = false,
    lcd_text: bool = false,
    no_nativetext: bool = false,
    grayscale: bool = false,

    reverse_byte_order: bool = false,
    convert_fill_to_stroke: bool = false,
    _padding_1: u1 = 0,
    debug_info: bool = false,

    no_catch: bool = false,
    limited_image_cache: bool = false,
    force_halftone: bool = false,
    printing: bool = false,

    no_smoothtext: bool = false,
    no_smoothimage: bool = false,
    no_smoothpath: bool = false,
    _padding_2: u1 = 0,

    _padding_3: u16 = 0,
};

comptime {
    assert(@sizeOf(BitmapRenderFlags) == @sizeOf(c_int));
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .annot = true })) == c.FPDF_ANNOT);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .lcd_text = true })) == c.FPDF_LCD_TEXT);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .no_nativetext = true })) == c.FPDF_NO_NATIVETEXT);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .grayscale = true })) == c.FPDF_GRAYSCALE);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .debug_info = true })) == c.FPDF_DEBUG_INFO);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .no_catch = true })) == c.FPDF_NO_CATCH);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .limited_image_cache = true })) == c.FPDF_RENDER_LIMITEDIMAGECACHE);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .force_halftone = true })) == c.FPDF_RENDER_FORCEHALFTONE);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .printing = true })) == c.FPDF_PRINTING);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .no_smoothtext = true })) == c.FPDF_RENDER_NO_SMOOTHTEXT);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .no_smoothimage = true })) == c.FPDF_RENDER_NO_SMOOTHIMAGE);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .no_smoothpath = true })) == c.FPDF_RENDER_NO_SMOOTHPATH);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .reverse_byte_order = true })) == c.FPDF_REVERSE_BYTE_ORDER);
    assert(@as(c_int, @bitCast(BitmapRenderFlags{ .convert_fill_to_stroke = true })) == c.FPDF_CONVERT_FILL_TO_STROKE);
}

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
        flags: BitmapRenderFlags,
    ) void {
        FPDF_RenderPageBitmap(@ptrCast(self), @ptrCast(page), x, y, width, height, rotate, @as(c_int, @bitCast(flags)));
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
            return error.IndexOutOfBounds;
        }
        return @intCast(result);
    }
};
pub const AnnotationSubtype = enum(c_int) {
    unknown = c.FPDF_ANNOT_UNKNOWN,
    text = c.FPDF_ANNOT_TEXT,
    link = c.FPDF_ANNOT_LINK,
    freetext = c.FPDF_ANNOT_FREETEXT,
    line = c.FPDF_ANNOT_LINE,
    square = c.FPDF_ANNOT_SQUARE,
    circle = c.FPDF_ANNOT_CIRCLE,
    polygon = c.FPDF_ANNOT_POLYGON,
    polyline = c.FPDF_ANNOT_POLYLINE,
    highlight = c.FPDF_ANNOT_HIGHLIGHT,
    underline = c.FPDF_ANNOT_UNDERLINE,
    squiggly = c.FPDF_ANNOT_SQUIGGLY,
    strikethrough = c.FPDF_ANNOT_STRIKEOUT,
    stamp = c.FPDF_ANNOT_STAMP,
    caret = c.FPDF_ANNOT_CARET,
    ink = c.FPDF_ANNOT_INK,
    popup = c.FPDF_ANNOT_POPUP,
    fileattachment = c.FPDF_ANNOT_FILEATTACHMENT,
    sound = c.FPDF_ANNOT_SOUND,
    movie = c.FPDF_ANNOT_MOVIE,
    widget = c.FPDF_ANNOT_WIDGET,
    screen = c.FPDF_ANNOT_SCREEN,
    printermark = c.FPDF_ANNOT_PRINTERMARK,
    trapnet = c.FPDF_ANNOT_TRAPNET,
    watermark = c.FPDF_ANNOT_WATERMARK,
    threed = c.FPDF_ANNOT_THREED,
    richmedia = c.FPDF_ANNOT_RICHMEDIA,
    xfawidget = c.FPDF_ANNOT_XFAWIDGET,
    redact = c.FPDF_ANNOT_REDACT,
};

pub const AnnotationRect = extern struct {
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
};
comptime {
    // Test equivalency with FS_RECTF from fpdfview.h
    const test_rect = AnnotationRect{
        .left = 1.0,
        .top = 2.0,
        .right = 3.0,
        .bottom = 4.0,
    };
    const test_c_rect = c.FS_RECTF{
        .left = 1.0,
        .top = 2.0,
        .right = 3.0,
        .bottom = 4.0,
    };
    assert(test_rect.left == test_c_rect.left);
    assert(test_rect.top == test_c_rect.top);
    assert(test_rect.right == test_c_rect.right);
    assert(test_rect.bottom == test_c_rect.bottom);
}

pub const Annotation = opaque {
    pub fn deinit(self: *Annotation) void {
        FPDFPage_CloseAnnot(@ptrCast(self));
    }

    pub fn getSubtype(self: *Annotation) AnnotationSubtype {
        return @enumFromInt(FPDFAnnot_GetSubtype(@ptrCast(self)));
    }

    pub fn getRect(self: *Annotation) !AnnotationRect {
        var rect: AnnotationRect = undefined;
        const success = FPDFAnnot_GetRect(@ptrCast(self), @ptrCast(&rect));
        if (success != 1) {
            return error.Failed;
        }
        return rect;
    }

    pub fn getLink(self: *Annotation) ?*Link {
        if (FPDFAnnot_GetLink(@ptrCast(self))) |link| {
            return @ptrCast(link);
        }
        return null;
    }
};

pub const Link = opaque {
    pub fn getDest(self: *Link, document: *Document) ?*Destination {
        if (FPDFLink_GetDest(@ptrCast(document), @ptrCast(self))) |dest| {
            return @ptrCast(dest);
        }
        return null;
    }

    pub fn getAction(self: *Link) ?*Action {
        if (FPDFLink_GetAction(@ptrCast(self))) |action| {
            return @ptrCast(action);
        }
        return null;
    }

    pub fn getAnnotationRect(self: *Link) !AnnotationRect {
        var rect: AnnotationRect = undefined;
        const success = FPDFLink_GetAnnotRect(@ptrCast(self), @ptrCast(&rect));
        if (success != 1) {
            return error.Failed;
        }
        return rect;
    }
};

pub const Destination = opaque {
    pub fn getDestPageIndex(self: *Destination, document: *Document) i32 {
        return FPDFDest_GetDestPageIndex(@ptrCast(document), @ptrCast(self));
    }
};

pub const Action = opaque {
    pub fn getDest(self: *Action, document: *Document) ?*Destination {
        if (FPDFAction_GetDest(@ptrCast(document), @ptrCast(self))) |dest| {
            return @ptrCast(dest);
        }
        return null;
    }
};

const UTF16_NUL = [_]u8{ 0, 0 };

pub const Bookmark = opaque {
    pub fn getFirstChild(self: *Bookmark, document: *Document) ?*Bookmark {
        if (FPDFBookmark_GetFirstChild(@ptrCast(document), @ptrCast(self))) |child| {
            return @ptrCast(child);
        }
        return null;
    }

    pub fn getNextSibling(self: *Bookmark, document: *Document) ?*Bookmark {
        if (FPDFBookmark_GetNextSibling(@ptrCast(document), @ptrCast(self))) |sibling| {
            return @ptrCast(sibling);
        }
        return null;
    }

    pub fn getTitle(self: *Bookmark, allocator: std.mem.Allocator) ![]u8 {
        const len: usize = @intCast(FPDFBookmark_GetTitle(@ptrCast(self), null, 0));
        const buffer = try allocator.alloc(u8, len);
        const check = FPDFBookmark_GetTitle(@ptrCast(self), buffer.ptr, @intCast(len));

        if (builtin.mode == .Debug) {
            // Sanity checks that pdfium works as documented.
            if (check != len) {
                log.err("FPDFBookmark_GetTitle returned {d} but expected {d}", .{ check, len });
                return error.Failed;
            }

            if (!std.mem.eql(u8, buffer[len - 2 ..], &UTF16_NUL)) {
                log.warn("Unexpected behaviour: pdfium response was not terminated with UTF-16 NUL characters", .{});
                return error.Failed;
            }
        }

        return buffer;
    }

    // Get the number of chlidren of |bookmark|.
    //
    //   bookmark - handle to the bookmark.
    //
    // Returns a signed integer that represents the number of sub-items the given
    // bookmark has. If the value is positive, child items shall be shown by default
    // (open state). If the value is negative, child items shall be hidden by
    // default (closed state). Please refer to PDF 32000-1:2008, Table 153.
    // Returns 0 if the bookmark has no children or is invalid.
    pub fn getCount(self: *Bookmark) i32 {
        return FPDFBookmark_GetCount(@ptrCast(self));
    }

    pub fn find(document: *Document, title: []const u8) ?*Bookmark {
        if (title.len < 2 or !std.mem.eql(u8, title[title.len - 2 ..], &UTF16_NUL)) {
            log.err("title must be terminated with UTF-16 NUL characters", .{});
            return null;
        }
        if (FPDFBookmark_Find(@ptrCast(document), title.ptr)) |bookmark| {
            return @ptrCast(bookmark);
        }
        return null;
    }

    pub fn getDest(self: *Bookmark, document: *Document) ?*Destination {
        if (FPDFBookmark_GetDest(@ptrCast(document), @ptrCast(self))) |dest| {
            return @ptrCast(dest);
        }
        return null;
    }

    pub fn getAction(self: *Bookmark) ?*Action {
        if (FPDFBookmark_GetAction(@ptrCast(self))) |action| {
            return @ptrCast(action);
        }
        return null;
    }
};
