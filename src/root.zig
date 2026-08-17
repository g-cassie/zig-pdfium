//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const builtin = @import("builtin");
pub const log = std.log.scoped(.pdfium);
const c = @cImport({
    @cInclude("fpdfview.h");
    @cInclude("fpdf_text.h");
    @cInclude("fpdf_doc.h");
    @cInclude("fpdf_annot.h");
    @cInclude("fpdf_save.h");
    @cInclude("fpdf_ppo.h");
    @cInclude("fpdf_edit.h");
    @cInclude("fpdf_structtree.h");
    // Also pulled in transitively by fpdf_annot.h, but the form-fill bindings
    // depend on it directly.
    @cInclude("fpdf_formfill.h");
});
const testing = std.testing;
const assert = std.debug.assert;
const panic = std.debug.panic;

pub const render = @import("ext/render.zig");
pub const save = @import("ext/save.zig");
pub const DynLib = @import("dynlib.zig").DynLib;

var DID_INIT: bool = false;
var IS_BOUND: bool = false;

/// Whether the form-fill APIs below were all resolved by `bindPdfium`. Unlike
/// every other binding they are looked up optionally, so a pdfium build that
/// ships without them degrades to "no form rendering" instead of failing to
/// start. Callers must not touch any `FORM_*`, `FPDF_FFLDraw`,
/// `FPDFDOC_*FormFillEnvironment` or `FPDFAnnot_*FormField*` symbol when this
/// is false — the wrappers in this file that can be reached without a
/// `FormHandle` check it for you.
pub var HAS_FORM_API: bool = false;

pub var c_pdfium: ?DynLib = null;
pub const FPDF_GRAYSCALE = c.FPDF_GRAYSCALE;
pub const FPDFBitmap_BGRA = c.FPDFBitmap_BGRA;

pub var FPDF_LoadDocument: *@TypeOf(c.FPDF_LoadDocument) = undefined;
pub var FPDF_InitLibrary: *@TypeOf(c.FPDF_InitLibrary) = undefined;
pub var FPDF_DestroyLibrary: *@TypeOf(c.FPDF_DestroyLibrary) = undefined;
pub var FPDF_GetPageCount: *@TypeOf(c.FPDF_GetPageCount) = undefined;
pub var FPDF_GetLastError: *@TypeOf(c.FPDF_GetLastError) = undefined;
pub var FPDF_CreateNewDocument: *@TypeOf(c.FPDF_CreateNewDocument) = undefined;
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
pub var FPDFText_GetBoundedText: *@TypeOf(c.FPDFText_GetBoundedText) = undefined;
pub var FPDFText_GetText: *@TypeOf(c.FPDFText_GetText) = undefined;
pub var FPDFText_CountChars: *@TypeOf(c.FPDFText_CountChars) = undefined;
pub var FPDFText_GetCharBox: *@TypeOf(c.FPDFText_GetCharBox) = undefined;
pub var FPDFText_GetUnicode: *@TypeOf(c.FPDFText_GetUnicode) = undefined;

// FPDFText_Find* functions
pub var FPDFText_FindStart: *@TypeOf(c.FPDFText_FindStart) = undefined;
pub var FPDFText_FindNext: *@TypeOf(c.FPDFText_FindNext) = undefined;
pub var FPDFText_FindPrev: *@TypeOf(c.FPDFText_FindPrev) = undefined;
pub var FPDFText_GetSchResultIndex: *@TypeOf(c.FPDFText_GetSchResultIndex) = undefined;
pub var FPDFText_GetSchCount: *@TypeOf(c.FPDFText_GetSchCount) = undefined;
pub var FPDFText_FindClose: *@TypeOf(c.FPDFText_FindClose) = undefined;

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
pub var FPDFLink_GetLinkAtPoint: *@TypeOf(c.FPDFLink_GetLinkAtPoint) = undefined;
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
pub var FPDF_SaveAsCopy: *@TypeOf(c.FPDF_SaveAsCopy) = undefined;
pub var FPDF_ImportPagesByIndex: *@TypeOf(c.FPDF_ImportPagesByIndex) = undefined;

// fpdf_edit.h - Page object APIs
pub var FPDFPage_CountObjects: *@TypeOf(c.FPDFPage_CountObjects) = undefined;
pub var FPDFPage_GetObject: *@TypeOf(c.FPDFPage_GetObject) = undefined;
pub var FPDFPageObj_GetType: *@TypeOf(c.FPDFPageObj_GetType) = undefined;
pub var FPDFPageObj_GetBounds: *@TypeOf(c.FPDFPageObj_GetBounds) = undefined;
pub var FPDFPageObj_GetStrokeWidth: *@TypeOf(c.FPDFPageObj_GetStrokeWidth) = undefined;
pub var FPDFPath_CountSegments: *@TypeOf(c.FPDFPath_CountSegments) = undefined;
pub var FPDFPath_GetPathSegment: *@TypeOf(c.FPDFPath_GetPathSegment) = undefined;
pub var FPDFPathSegment_GetType: *@TypeOf(c.FPDFPathSegment_GetType) = undefined;
pub var FPDFPathSegment_GetPoint: *@TypeOf(c.FPDFPathSegment_GetPoint) = undefined;
pub var FPDFPathSegment_GetClose: *@TypeOf(c.FPDFPathSegment_GetClose) = undefined;
pub var FPDFPath_GetDrawMode: *@TypeOf(c.FPDFPath_GetDrawMode) = undefined;
pub var FPDFFormObj_CountObjects: *@TypeOf(c.FPDFFormObj_CountObjects) = undefined;
pub var FPDFFormObj_GetObject: *@TypeOf(c.FPDFFormObj_GetObject) = undefined;

// Page object type constants
pub const FPDF_PAGEOBJ_TEXT = c.FPDF_PAGEOBJ_TEXT;
pub const FPDF_PAGEOBJ_PATH = c.FPDF_PAGEOBJ_PATH;
pub const FPDF_PAGEOBJ_IMAGE = c.FPDF_PAGEOBJ_IMAGE;
pub const FPDF_PAGEOBJ_SHADING = c.FPDF_PAGEOBJ_SHADING;
pub const FPDF_PAGEOBJ_FORM = c.FPDF_PAGEOBJ_FORM;

// Path segment type constants
pub const FPDF_SEGMENT_LINETO = c.FPDF_SEGMENT_LINETO;
pub const FPDF_SEGMENT_BEZIERTO = c.FPDF_SEGMENT_BEZIERTO;
pub const FPDF_SEGMENT_MOVETO = c.FPDF_SEGMENT_MOVETO;

// fpdf_structtree.h - Structure tree APIs
pub var FPDF_StructTree_GetForPage: *@TypeOf(c.FPDF_StructTree_GetForPage) = undefined;
pub var FPDF_StructTree_Close: *@TypeOf(c.FPDF_StructTree_Close) = undefined;
pub var FPDF_StructTree_CountChildren: *@TypeOf(c.FPDF_StructTree_CountChildren) = undefined;
pub var FPDF_StructTree_GetChildAtIndex: *@TypeOf(c.FPDF_StructTree_GetChildAtIndex) = undefined;
pub var FPDF_StructElement_GetType: *@TypeOf(c.FPDF_StructElement_GetType) = undefined;
pub var FPDF_StructElement_CountChildren: *@TypeOf(c.FPDF_StructElement_CountChildren) = undefined;
pub var FPDF_StructElement_GetChildAtIndex: *@TypeOf(c.FPDF_StructElement_GetChildAtIndex) = undefined;
pub var FPDF_StructElement_GetMarkedContentID: *@TypeOf(c.FPDF_StructElement_GetMarkedContentID) = undefined;
pub var FPDF_StructElement_GetChildMarkedContentID: *@TypeOf(c.FPDF_StructElement_GetChildMarkedContentID) = undefined;
pub var FPDF_StructElement_GetAttributeCount: *@TypeOf(c.FPDF_StructElement_GetAttributeCount) = undefined;
pub var FPDF_StructElement_GetAttributeAtIndex: *@TypeOf(c.FPDF_StructElement_GetAttributeAtIndex) = undefined;
pub var FPDF_StructElement_Attr_GetValue: *@TypeOf(c.FPDF_StructElement_Attr_GetValue) = undefined;
pub var FPDF_StructElement_Attr_GetNumberValue: *@TypeOf(c.FPDF_StructElement_Attr_GetNumberValue) = undefined;
pub var FPDF_StructElement_GetAltText: *@TypeOf(c.FPDF_StructElement_GetAltText) = undefined;
pub var FPDF_StructElement_GetMarkedContentIdCount: *@TypeOf(c.FPDF_StructElement_GetMarkedContentIdCount) = undefined;
pub var FPDF_StructElement_GetMarkedContentIdAtIndex: *@TypeOf(c.FPDF_StructElement_GetMarkedContentIdAtIndex) = undefined;

// fpdf_text.h - Text object mapping
pub var FPDFText_GetTextObject: *@TypeOf(c.FPDFText_GetTextObject) = undefined;

// fpdf_edit.h - Page object marked content
pub var FPDFPageObj_GetMarkedContentID: *@TypeOf(c.FPDFPageObj_GetMarkedContentID) = undefined;

// fpdf_formfill.h - Form fill environment.
// Only valid when `HAS_FORM_API` is true.
pub var FPDFDOC_InitFormFillEnvironment: *@TypeOf(c.FPDFDOC_InitFormFillEnvironment) = undefined;
pub var FPDFDOC_ExitFormFillEnvironment: *@TypeOf(c.FPDFDOC_ExitFormFillEnvironment) = undefined;
pub var FPDF_FFLDraw: *@TypeOf(c.FPDF_FFLDraw) = undefined;
pub var FPDF_GetFormType: *@TypeOf(c.FPDF_GetFormType) = undefined;
pub var FORM_OnAfterLoadPage: *@TypeOf(c.FORM_OnAfterLoadPage) = undefined;
pub var FORM_OnBeforeClosePage: *@TypeOf(c.FORM_OnBeforeClosePage) = undefined;
pub var FPDF_SetFormFieldHighlightColor: *@TypeOf(c.FPDF_SetFormFieldHighlightColor) = undefined;
pub var FPDF_SetFormFieldHighlightAlpha: *@TypeOf(c.FPDF_SetFormFieldHighlightAlpha) = undefined;

// fpdf_annot.h - Form field accessors. All take an FPDF_FORMHANDLE, so they
// are equally gated on `HAS_FORM_API`.
pub var FPDFAnnot_GetFormFieldType: *@TypeOf(c.FPDFAnnot_GetFormFieldType) = undefined;
pub var FPDFAnnot_GetFormFieldName: *@TypeOf(c.FPDFAnnot_GetFormFieldName) = undefined;
pub var FPDFAnnot_GetFormFieldAlternateName: *@TypeOf(c.FPDFAnnot_GetFormFieldAlternateName) = undefined;
pub var FPDFAnnot_GetFormFieldValue: *@TypeOf(c.FPDFAnnot_GetFormFieldValue) = undefined;
pub var FPDFAnnot_GetFormFieldFlags: *@TypeOf(c.FPDFAnnot_GetFormFieldFlags) = undefined;
pub var FPDFAnnot_GetFormFieldExportValue: *@TypeOf(c.FPDFAnnot_GetFormFieldExportValue) = undefined;
pub var FPDFAnnot_GetFormFieldAtPoint: *@TypeOf(c.FPDFAnnot_GetFormFieldAtPoint) = undefined;
pub var FPDFAnnot_IsChecked: *@TypeOf(c.FPDFAnnot_IsChecked) = undefined;
pub var FPDFAnnot_GetOptionCount: *@TypeOf(c.FPDFAnnot_GetOptionCount) = undefined;
pub var FPDFAnnot_GetOptionLabel: *@TypeOf(c.FPDFAnnot_GetOptionLabel) = undefined;
pub var FPDFAnnot_IsOptionSelected: *@TypeOf(c.FPDFAnnot_IsOptionSelected) = undefined;

// fpdf_annot.h - Annotation flags. Not form-specific, but an "Experimental API"
// like the block above, and its only caller today is the form-field walk (which
// uses it to skip widgets pdfium won't draw), so it shares `HAS_FORM_API` rather
// than introducing a second capability flag. Split it out if a non-form caller
// appears.
pub var FPDFAnnot_GetFlags: *@TypeOf(c.FPDFAnnot_GetFlags) = undefined;

pub fn bindPdfium(path: []const u8) !void {
    if (IS_BOUND) {
        log.warn("PDFium already bound", .{});
        return;
    }
    defer IS_BOUND = true;
    c_pdfium = try DynLib.open(path);

    // Top Level Methods
    FPDF_InitLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_InitLibrary), "FPDF_InitLibrary").?;
    FPDF_DestroyLibrary = c_pdfium.?.lookup(@TypeOf(FPDF_DestroyLibrary), "FPDF_DestroyLibrary").?;
    FPDF_GetLastError = c_pdfium.?.lookup(@TypeOf(FPDF_GetLastError), "FPDF_GetLastError").?;
    FPDF_CreateNewDocument = c_pdfium.?.lookup(@TypeOf(FPDF_CreateNewDocument), "FPDF_CreateNewDocument").?;

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
    FPDFText_GetBoundedText = c_pdfium.?.lookup(@TypeOf(FPDFText_GetBoundedText), "FPDFText_GetBoundedText").?;
    FPDFText_GetText = c_pdfium.?.lookup(@TypeOf(FPDFText_GetText), "FPDFText_GetText").?;
    FPDFText_CountChars = c_pdfium.?.lookup(@TypeOf(FPDFText_CountChars), "FPDFText_CountChars").?;
    FPDFText_GetCharBox = c_pdfium.?.lookup(@TypeOf(FPDFText_GetCharBox), "FPDFText_GetCharBox").?;
    FPDFText_GetUnicode = c_pdfium.?.lookup(@TypeOf(FPDFText_GetUnicode), "FPDFText_GetUnicode").?;

    // FPDFText_Find* functions
    FPDFText_FindStart = c_pdfium.?.lookup(@TypeOf(FPDFText_FindStart), "FPDFText_FindStart").?;
    FPDFText_FindNext = c_pdfium.?.lookup(@TypeOf(FPDFText_FindNext), "FPDFText_FindNext").?;
    FPDFText_FindPrev = c_pdfium.?.lookup(@TypeOf(FPDFText_FindPrev), "FPDFText_FindPrev").?;
    FPDFText_GetSchResultIndex = c_pdfium.?.lookup(@TypeOf(FPDFText_GetSchResultIndex), "FPDFText_GetSchResultIndex").?;
    FPDFText_GetSchCount = c_pdfium.?.lookup(@TypeOf(FPDFText_GetSchCount), "FPDFText_GetSchCount").?;
    FPDFText_FindClose = c_pdfium.?.lookup(@TypeOf(FPDFText_FindClose), "FPDFText_FindClose").?;

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
    FPDFLink_GetLinkAtPoint = c_pdfium.?.lookup(@TypeOf(FPDFLink_GetLinkAtPoint), "FPDFLink_GetLinkAtPoint").?;
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
    FPDF_SaveAsCopy = c_pdfium.?.lookup(@TypeOf(FPDF_SaveAsCopy), "FPDF_SaveAsCopy").?;
    FPDF_ImportPagesByIndex = c_pdfium.?.lookup(@TypeOf(FPDF_ImportPagesByIndex), "FPDF_ImportPagesByIndex").?;

    // fpdf_edit.h - Page object APIs
    FPDFPage_CountObjects = c_pdfium.?.lookup(@TypeOf(FPDFPage_CountObjects), "FPDFPage_CountObjects").?;
    FPDFPage_GetObject = c_pdfium.?.lookup(@TypeOf(FPDFPage_GetObject), "FPDFPage_GetObject").?;
    FPDFPageObj_GetType = c_pdfium.?.lookup(@TypeOf(FPDFPageObj_GetType), "FPDFPageObj_GetType").?;
    FPDFPageObj_GetBounds = c_pdfium.?.lookup(@TypeOf(FPDFPageObj_GetBounds), "FPDFPageObj_GetBounds").?;
    FPDFPageObj_GetStrokeWidth = c_pdfium.?.lookup(@TypeOf(FPDFPageObj_GetStrokeWidth), "FPDFPageObj_GetStrokeWidth").?;
    FPDFPath_CountSegments = c_pdfium.?.lookup(@TypeOf(FPDFPath_CountSegments), "FPDFPath_CountSegments").?;
    FPDFPath_GetPathSegment = c_pdfium.?.lookup(@TypeOf(FPDFPath_GetPathSegment), "FPDFPath_GetPathSegment").?;
    FPDFPathSegment_GetType = c_pdfium.?.lookup(@TypeOf(FPDFPathSegment_GetType), "FPDFPathSegment_GetType").?;
    FPDFPathSegment_GetPoint = c_pdfium.?.lookup(@TypeOf(FPDFPathSegment_GetPoint), "FPDFPathSegment_GetPoint").?;
    FPDFPathSegment_GetClose = c_pdfium.?.lookup(@TypeOf(FPDFPathSegment_GetClose), "FPDFPathSegment_GetClose").?;
    FPDFPath_GetDrawMode = c_pdfium.?.lookup(@TypeOf(FPDFPath_GetDrawMode), "FPDFPath_GetDrawMode").?;
    FPDFFormObj_CountObjects = c_pdfium.?.lookup(@TypeOf(FPDFFormObj_CountObjects), "FPDFFormObj_CountObjects").?;
    FPDFFormObj_GetObject = c_pdfium.?.lookup(@TypeOf(FPDFFormObj_GetObject), "FPDFFormObj_GetObject").?;

    // fpdf_structtree.h
    FPDF_StructTree_GetForPage = c_pdfium.?.lookup(@TypeOf(FPDF_StructTree_GetForPage), "FPDF_StructTree_GetForPage").?;
    FPDF_StructTree_Close = c_pdfium.?.lookup(@TypeOf(FPDF_StructTree_Close), "FPDF_StructTree_Close").?;
    FPDF_StructTree_CountChildren = c_pdfium.?.lookup(@TypeOf(FPDF_StructTree_CountChildren), "FPDF_StructTree_CountChildren").?;
    FPDF_StructTree_GetChildAtIndex = c_pdfium.?.lookup(@TypeOf(FPDF_StructTree_GetChildAtIndex), "FPDF_StructTree_GetChildAtIndex").?;
    FPDF_StructElement_GetType = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetType), "FPDF_StructElement_GetType").?;
    FPDF_StructElement_CountChildren = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_CountChildren), "FPDF_StructElement_CountChildren").?;
    FPDF_StructElement_GetChildAtIndex = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetChildAtIndex), "FPDF_StructElement_GetChildAtIndex").?;
    FPDF_StructElement_GetMarkedContentID = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetMarkedContentID), "FPDF_StructElement_GetMarkedContentID").?;
    FPDF_StructElement_GetChildMarkedContentID = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetChildMarkedContentID), "FPDF_StructElement_GetChildMarkedContentID").?;
    FPDF_StructElement_GetAttributeCount = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetAttributeCount), "FPDF_StructElement_GetAttributeCount").?;
    FPDF_StructElement_GetAttributeAtIndex = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetAttributeAtIndex), "FPDF_StructElement_GetAttributeAtIndex").?;
    FPDF_StructElement_Attr_GetValue = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_Attr_GetValue), "FPDF_StructElement_Attr_GetValue").?;
    FPDF_StructElement_Attr_GetNumberValue = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_Attr_GetNumberValue), "FPDF_StructElement_Attr_GetNumberValue").?;
    FPDF_StructElement_GetAltText = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetAltText), "FPDF_StructElement_GetAltText").?;
    FPDF_StructElement_GetMarkedContentIdCount = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetMarkedContentIdCount), "FPDF_StructElement_GetMarkedContentIdCount").?;
    FPDF_StructElement_GetMarkedContentIdAtIndex = c_pdfium.?.lookup(@TypeOf(FPDF_StructElement_GetMarkedContentIdAtIndex), "FPDF_StructElement_GetMarkedContentIdAtIndex").?;
    FPDFText_GetTextObject = c_pdfium.?.lookup(@TypeOf(FPDFText_GetTextObject), "FPDFText_GetTextObject").?;
    FPDFPageObj_GetMarkedContentID = c_pdfium.?.lookup(@TypeOf(FPDFPageObj_GetMarkedContentID), "FPDFPageObj_GetMarkedContentID").?;

    // fpdf_formfill.h + the FPDFAnnot_*FormField* accessors from fpdf_annot.h.
    //
    // Looked up optionally rather than with `.?`: these are the only bindings
    // whose absence has a sensible fallback (render and extract without form
    // fields), and every one of them is an "Experimental API" that a stripped
    // or older build could plausibly omit. If any is missing we leave
    // HAS_FORM_API false and no caller reaches the rest.
    form: {
        FPDFDOC_InitFormFillEnvironment = c_pdfium.?.lookup(@TypeOf(FPDFDOC_InitFormFillEnvironment), "FPDFDOC_InitFormFillEnvironment") orelse break :form;
        FPDFDOC_ExitFormFillEnvironment = c_pdfium.?.lookup(@TypeOf(FPDFDOC_ExitFormFillEnvironment), "FPDFDOC_ExitFormFillEnvironment") orelse break :form;
        FPDF_FFLDraw = c_pdfium.?.lookup(@TypeOf(FPDF_FFLDraw), "FPDF_FFLDraw") orelse break :form;
        FPDF_GetFormType = c_pdfium.?.lookup(@TypeOf(FPDF_GetFormType), "FPDF_GetFormType") orelse break :form;
        FORM_OnAfterLoadPage = c_pdfium.?.lookup(@TypeOf(FORM_OnAfterLoadPage), "FORM_OnAfterLoadPage") orelse break :form;
        FORM_OnBeforeClosePage = c_pdfium.?.lookup(@TypeOf(FORM_OnBeforeClosePage), "FORM_OnBeforeClosePage") orelse break :form;
        FPDF_SetFormFieldHighlightColor = c_pdfium.?.lookup(@TypeOf(FPDF_SetFormFieldHighlightColor), "FPDF_SetFormFieldHighlightColor") orelse break :form;
        FPDF_SetFormFieldHighlightAlpha = c_pdfium.?.lookup(@TypeOf(FPDF_SetFormFieldHighlightAlpha), "FPDF_SetFormFieldHighlightAlpha") orelse break :form;

        FPDFAnnot_GetFormFieldType = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldType), "FPDFAnnot_GetFormFieldType") orelse break :form;
        FPDFAnnot_GetFormFieldName = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldName), "FPDFAnnot_GetFormFieldName") orelse break :form;
        FPDFAnnot_GetFormFieldAlternateName = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldAlternateName), "FPDFAnnot_GetFormFieldAlternateName") orelse break :form;
        FPDFAnnot_GetFormFieldValue = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldValue), "FPDFAnnot_GetFormFieldValue") orelse break :form;
        FPDFAnnot_GetFormFieldFlags = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldFlags), "FPDFAnnot_GetFormFieldFlags") orelse break :form;
        FPDFAnnot_GetFormFieldExportValue = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldExportValue), "FPDFAnnot_GetFormFieldExportValue") orelse break :form;
        FPDFAnnot_GetFormFieldAtPoint = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFormFieldAtPoint), "FPDFAnnot_GetFormFieldAtPoint") orelse break :form;
        FPDFAnnot_IsChecked = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_IsChecked), "FPDFAnnot_IsChecked") orelse break :form;
        FPDFAnnot_GetOptionCount = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetOptionCount), "FPDFAnnot_GetOptionCount") orelse break :form;
        FPDFAnnot_GetOptionLabel = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetOptionLabel), "FPDFAnnot_GetOptionLabel") orelse break :form;
        FPDFAnnot_IsOptionSelected = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_IsOptionSelected), "FPDFAnnot_IsOptionSelected") orelse break :form;

        FPDFAnnot_GetFlags = c_pdfium.?.lookup(@TypeOf(FPDFAnnot_GetFlags), "FPDFAnnot_GetFlags") orelse break :form;

        HAS_FORM_API = true;
    }
    if (!HAS_FORM_API) {
        log.warn("pdfium is missing the form-fill APIs; fillable form fields will not render or extract", .{});
    }
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
    pub fn createNew() !*Document {
        assertLoaded();
        if (FPDF_CreateNewDocument()) |doc| {
            return @ptrCast(doc);
        } else {
            return error.Failed;
        }
    }

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

    pub fn saveAsCopy(self: *Document, file_write: *FileWrite, flags: SaveFlags) !void {
        const success = FPDF_SaveAsCopy(@ptrCast(self), @ptrCast(file_write), @intFromEnum(flags));
        if (success == 0) {
            return getLastError();
        }
    }

    /// What kind of interactive form, if any, this document has. Cheap: it is
    /// an `/AcroForm` dictionary lookup, so it is the right thing to gate the
    /// (much more expensive) `initFormFillEnv` on.
    ///
    /// Returns `.none` when the pdfium build has no form APIs.
    pub fn getFormType(self: *Document) FormType {
        if (!HAS_FORM_API) return .none;
        return std.enums.fromInt(FormType, FPDF_GetFormType(@ptrCast(self))) orelse .none;
    }

    /// Create the form fill environment for this document. Required before any
    /// `FormHandle` operation, including `Bitmap.drawFormFields`: widget
    /// annotations are *not* drawn by `renderPage`, even with `.annot = true`.
    ///
    /// `info` must remain valid, at a stable address, until the returned
    /// handle is closed with `FormHandle.deinit` — pdfium retains the pointer
    /// (fpdf_formfill.h:1055). Store it somewhere that outlives the handle;
    /// a local will not do.
    ///
    /// Returns null when the pdfium build has no form APIs, or when pdfium
    /// declines to create the environment.
    pub fn initFormFillEnv(self: *Document, info: *FormFillInfo) ?*FormHandle {
        if (!HAS_FORM_API) return null;
        if (FPDFDOC_InitFormFillEnvironment(@ptrCast(self), info)) |handle| {
            return @ptrCast(handle);
        }
        return null;
    }
};

pub const FormType = enum(c_int) {
    none = c.FORMTYPE_NONE,
    acro_form = c.FORMTYPE_ACRO_FORM,
    xfa_full = c.FORMTYPE_XFA_FULL,
    xfa_foreground = c.FORMTYPE_XFA_FOREGROUND,
};

/// translate-c's version of `FPDF_FORMFILLINFO`, re-exported rather than
/// hand-rolled: it is a 40-plus member table of function pointers, and a
/// silent ABI mismatch in it corrupts pdfium's callback dispatch.
///
/// This is a value type on purpose — the caller has to own the storage,
/// see `Document.initFormFillEnv`.
pub const FormFillInfo = c.FPDF_FORMFILLINFO;

/// A zeroed version-1 `FormFillInfo`: no callbacks at all.
///
/// Every version-1 callback is documented "Implementation Required: No"
/// except `FFI_GetCurrentPage`, which is only called when pdfium is built
/// with V8/JavaScript. Version 1 (rather than 2) is correct for a build
/// without XFA.
pub fn defaultFormFillInfo() FormFillInfo {
    var info = std.mem.zeroes(FormFillInfo);
    info.version = 1;
    return info;
}

/// A live form fill environment, from `Document.initFormFillEnv`. Must be
/// closed with `deinit` *before* the document it came from is closed.
pub const FormHandle = opaque {
    pub fn deinit(self: *FormHandle) void {
        FPDFDOC_ExitFormFillEnvironment(@ptrCast(self));
    }

    /// Set the tint `drawFormFields` paints over form fields, and switch that
    /// tint *on*: pdfium draws no highlight at all until this is called, so a
    /// viewer that wants the document to look like it prints should simply
    /// never call it. `setFieldHighlightAlpha` alone does not enable it.
    ///
    /// `field_type` of `.unknown` applies to every field in the document.
    ///
    /// `color` is `0x00bbggrr` — pdfium's `FX_COLORREF`, i.e. red is
    /// `0x000000FF`. Note that fpdf_formfill.h documents this parameter as
    /// `0xxxrrggbb`; the header is wrong, verified against pdfium 7215 in
    /// "form: field highlight is opt-in" below.
    pub fn setFieldHighlightColor(self: *FormHandle, field_type: FormFieldType, color: u32) void {
        FPDF_SetFormFieldHighlightColor(@ptrCast(self), @intFromEnum(field_type), @as(c_ulong, color));
    }

    /// Set the opacity, 0-255, of the highlight enabled by
    /// `setFieldHighlightColor`. Has no effect on its own.
    pub fn setFieldHighlightAlpha(self: *FormHandle, alpha: u8) void {
        FPDF_SetFormFieldHighlightAlpha(@ptrCast(self), alpha);
    }
};

pub const SaveFlags = enum(c_uint) {
    none = 0,
    incremental = c.FPDF_INCREMENTAL,
    no_incremental = c.FPDF_NO_INCREMENTAL,
    remove_security = c.FPDF_REMOVE_SECURITY,
};

pub const FileWrite = extern struct {
    version: c_int,
    write_block: *const fn (self: *FileWrite, data: [*c]const u8, size: c_long) callconv(.c) c_int,
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

    pub fn getLinkAtPoint(self: *Page, x: f64, y: f64) ?*Link {
        if (FPDFLink_GetLinkAtPoint(@ptrCast(self), x, y)) |link| {
            return @ptrCast(link);
        }
        return null;
    }

    pub fn linkIterator(self: *Page) LinkIterator {
        return LinkIterator{
            .index = 0,
            .page = self,
        };
    }

    /// Tell the form fill environment this page was loaded. Required before
    /// any form operation on the page: `FPDF_FFLDraw` otherwise has no page
    /// view to draw into.
    ///
    /// Must be paired with `formOnBeforeClose` before `deinit`, or the form
    /// environment is left holding a dangling page pointer.
    pub fn formOnAfterLoad(self: *Page, form_handle: *FormHandle) void {
        FORM_OnAfterLoadPage(@ptrCast(self), @ptrCast(form_handle));
    }

    /// The other half of `formOnAfterLoad`. Call immediately before `deinit`.
    pub fn formOnBeforeClose(self: *Page, form_handle: *FormHandle) void {
        FORM_OnBeforeClosePage(@ptrCast(self), @ptrCast(form_handle));
    }

    /// The widget annotation whose rectangle contains (`x`, `y`), in PDF user
    /// space (bottom-left origin, points).
    ///
    /// The caller owns the result and must `deinit` it.
    pub fn getFormFieldAnnotAtPoint(self: *Page, form_handle: *FormHandle, x: f32, y: f32) ?*Annotation {
        const point = c.FS_POINTF{ .x = x, .y = y };
        if (FPDFAnnot_GetFormFieldAtPoint(@ptrCast(form_handle), @ptrCast(self), &point)) |annot| {
            return @ptrCast(annot);
        }
        return null;
    }
};

pub const BitmapFormat = enum(c_int) {
    unknown = c.FPDFBitmap_Unknown,
    gray = c.FPDFBitmap_Gray,
    bgr = c.FPDFBitmap_BGR,
    bgrx = c.FPDFBitmap_BGRx,
    bgra = c.FPDFBitmap_BGRA,
    bgra_premul = c.FPDFBitmap_BGRA_Premul,
};

pub const BitmapRenderFlags = packed struct {
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
    pub const ARGBColor = if (@sizeOf(c_ulong) == 8)
        packed struct(c_ulong) { _padding: u32 = 0, a: u8, r: u8, g: u8, b: u8 }
    else
        packed struct(c_ulong) { a: u8, r: u8, g: u8, b: u8 };
    pub fn initEx(width: c_int, height: c_int, format: BitmapFormat, buffer: []u8, stride: c_int) !*Bitmap {
        assertLoaded();
        const fpdf_bitmap = FPDFBitmap_CreateEx(width, height, @intFromEnum(format), buffer.ptr, stride);
        if (fpdf_bitmap == null) {
            return error.ParameterError;
        }
        return @ptrCast(fpdf_bitmap.?);
    }

    pub fn fillRect(self: *Bitmap, x: c_int, y: c_int, width: c_int, height: c_int, color: ARGBColor) !void {
        const success = FPDFBitmap_FillRect(@ptrCast(self), x, y, width, height, @bitCast(color));
        if (success != 1) {
            return error.Failed;
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

    /// Draw the page's form fields (widget annotations) over what is already
    /// in the bitmap. `renderPage` does not draw them — not even with
    /// `.annot = true`, which only covers *static* annotation appearance
    /// streams — so a fillable form renders blank without this call.
    ///
    /// Takes the same geometry and flags as `renderPage`; pass the same
    /// values you passed there, and call it immediately after. `page` must
    /// have had `formOnAfterLoad` called on it with this same handle.
    pub fn drawFormFields(
        self: *Bitmap,
        form_handle: *FormHandle,
        page: *Page,
        x: c_int,
        y: c_int,
        width: c_int,
        height: c_int,
        rotate: c_int,
        flags: BitmapRenderFlags,
    ) void {
        FPDF_FFLDraw(
            @ptrCast(form_handle),
            @ptrCast(self),
            @ptrCast(page),
            x,
            y,
            width,
            height,
            rotate,
            @as(c_int, @bitCast(flags)),
        );
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

pub const SearchFlags = packed struct {
    match_case: bool = false,
    match_whole_word: bool = false,
    consecutive: bool = false,
    _padding: u29 = 0,
};

comptime {
    assert(@sizeOf(SearchFlags) == @sizeOf(c_uint));
    assert(@as(c_uint, @bitCast(SearchFlags{ .match_case = true })) == c.FPDF_MATCHCASE);
    assert(@as(c_uint, @bitCast(SearchFlags{ .match_whole_word = true })) == c.FPDF_MATCHWHOLEWORD);
    assert(@as(c_uint, @bitCast(SearchFlags{ .consecutive = true })) == c.FPDF_CONSECUTIVE);
}

pub const TextPage = opaque {
    pub fn deinit(self: *TextPage) void {
        FPDFText_ClosePage(@ptrCast(self));
    }

    // Note: it seems like you need to call countRects before calling this or it will not work.
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

    /// Extract text within a rectangular boundary on the page.
    /// If buffer is null or buflen is zero, returns the number of UTF-16 values needed.
    /// Otherwise, copies the text into the buffer and returns the number of UTF-16 values copied.
    /// The text is in UTF-16 format and includes a terminating NUL if space is available.
    pub fn getBoundedText(
        self: *TextPage,
        rect: TextPageRect,
        allocator: std.mem.Allocator,
    ) ![]u16 {
        // First call to get required length
        const len: usize = @intCast(FPDFText_GetBoundedText(
            @ptrCast(self),
            rect.left,
            rect.top,
            rect.right,
            rect.bottom,
            null,
            0,
        ));

        // Allocate buffer
        const buffer = try allocator.alloc(u16, len);
        errdefer allocator.free(buffer);

        // Second call to get actual text
        const copied: usize = @intCast(FPDFText_GetBoundedText(
            @ptrCast(self),
            rect.left,
            rect.top,
            rect.right,
            rect.bottom,
            @ptrCast(buffer.ptr),
            @intCast(buffer.len),
        ));

        if (copied != buffer.len) {
            log.warn("FPDFText_GetBoundedText returned {d} but expected {d}", .{ copied, buffer.len });
            return error.Failed;
        }

        return buffer;
    }

    pub fn countChars(self: *TextPage) !usize {
        const result = FPDFText_CountChars(@ptrCast(self));
        if (result < 0) {
            return error.Failed;
        }
        return @intCast(result);
    }

    pub fn getCharBox(self: *TextPage, index: usize) !struct { left: f64, right: f64, bottom: f64, top: f64 } {
        var left: f64 = 0;
        var right: f64 = 0;
        var bottom: f64 = 0;
        var top: f64 = 0;

        const success = FPDFText_GetCharBox(@ptrCast(self), @intCast(index), &left, &right, &bottom, &top);
        if (success != 1) {
            return error.Failed;
        }

        return .{
            .left = left,
            .right = right,
            .bottom = bottom,
            .top = top,
        };
    }

    pub fn getUnicode(self: *TextPage, index: usize) !u32 {
        const result = FPDFText_GetUnicode(@ptrCast(self), @intCast(index));
        if (result == 0) {
            return error.Failed;
        }
        return @intCast(result);
    }

    pub fn getText(
        self: *TextPage,
        allocator: std.mem.Allocator,
        start_index: usize,
        count: ?usize,
    ) ![:0]u16 {
        const char_count: c_int = b: {
            if (count) |x| {
                break :b @intCast(x);
            } else {
                const total_chars = try self.countChars();
                if (start_index > total_chars) {
                    return error.IndexOutOfRange;
                }
                break :b @intCast(total_chars - start_index);
            }
        };
        if (char_count < 0) unreachable;
        if (char_count == 0) {
            return std.mem.concatWithSentinel(allocator, u16, &.{}, 0);
        }

        // Allocate buffer for char_count + 1 (for terminator)
        const buf_len: usize = @intCast(char_count + 1);
        var buffer = try allocator.alloc(u16, buf_len);
        errdefer allocator.free(buffer);

        // Call FPDFText_GetText
        const copied: usize = @intCast(FPDFText_GetText(
            @ptrCast(self),
            @as(c_int, @intCast(start_index)),
            char_count,
            @ptrCast(buffer.ptr),
        ));

        // It seems like there are circumstances where FPDFText_GetText will write less than the
        // number of characters returend by `FPDFText_CountChars`.  This seems to occur when
        // there are sketchy characters that render as boxes with a typical PDF viewer.  If you
        // shorten the buffer the length returned by FPDFText_GetText, everything seems to work
        // fine (the sketchy characters are still sketchy). If you do not shorten it you will
        // get corruption from the undefined characters at the end of the buffer.
        const actual_len = @min(buffer.len, copied);
        if (actual_len != buffer.len) {
            log.debug("FPDFText_GetText wrote {d} characters but it expected {d}", .{
                copied,
                buffer.len,
            });
            buffer = try allocator.realloc(buffer, actual_len);
        }

        assert(buffer.len == actual_len);
        return buffer[0 .. buffer.len - 1 :0];
    }

    /// Start a search for text on this page.
    ///
    /// Parameters:
    ///   findwhat    - A unicode match pattern (UTF-16)
    ///   flags       - Search option flags
    ///   start_index - Start from this character. null for end of the page.
    ///
    /// Returns a SearchHandle that must be closed with deinit().
    pub fn findStart(
        self: *TextPage,
        findwhat: []const u16,
        flags: SearchFlags,
        start_index: ?i32,
    ) !*SearchHandle {
        const start_index_c: c_int = if (start_index) |x| @intCast(x) else -1;
        if (FPDFText_FindStart(@ptrCast(self), @ptrCast(findwhat.ptr), @as(c_uint, @bitCast(flags)), start_index_c)) |handle| {
            return @ptrCast(handle);
        } else {
            return error.SearchFailed;
        }
    }
};

pub const SearchHandle = opaque {
    /// Search in the direction from page start to end.
    /// Returns true if a match is found, false otherwise.
    pub fn findNext(self: *SearchHandle) bool {
        return FPDFText_FindNext(@ptrCast(self)) != 0;
    }

    /// Search in the direction from page end to start.
    /// Returns true if a match is found, false otherwise.
    pub fn findPrev(self: *SearchHandle) bool {
        return FPDFText_FindPrev(@ptrCast(self)) != 0;
    }

    /// Get the starting character index of the search result.
    /// Returns the index for the starting character.
    pub fn getResultIndex(self: *SearchHandle) usize {
        return @intCast(FPDFText_GetSchResultIndex(@ptrCast(self)));
    }

    /// Get the number of matched characters in the search result.
    /// Returns the number of matched characters.
    pub fn getCount(self: *SearchHandle) usize {
        return @intCast(FPDFText_GetSchCount(@ptrCast(self)));
    }

    /// Release the search context.
    /// This must be called to free resources.
    pub fn deinit(self: *SearchHandle) void {
        FPDFText_FindClose(@ptrCast(self));
    }
};

test "getBoundedText" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();
    const page = try test_pdf.loadPage(0);
    defer page.deinit();

    const text_page = try page.loadTextPage();
    defer text_page.deinit();

    try testing.expect(try text_page.countRects(0, null) > 0);

    const rect = try text_page.getRect(1);
    const text = try text_page.getBoundedText(rect, testing.allocator);
    defer testing.allocator.free(text);

    const utf8_text = try std.unicode.utf16LeToUtf8Alloc(testing.allocator, text);
    defer testing.allocator.free(utf8_text);

    try testing.expectEqualStrings("Introduction", utf8_text);
}

test "text search" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();
    const page = try test_pdf.loadPage(0);
    defer page.deinit();

    const text_page = try page.loadTextPage();
    defer text_page.deinit();

    // Convert "Introduction" to UTF-16
    const search_text = try std.unicode.utf8ToUtf16LeAllocZ(testing.allocator, "Introduction");
    defer testing.allocator.free(search_text);

    const search_handle = try text_page.findStart(search_text, .{}, 0);
    defer search_handle.deinit();

    // Should find the first occurrence
    try testing.expect(search_handle.findNext());

    const result_index = search_handle.getResultIndex();
    const result_count = search_handle.getCount();

    try testing.expect(result_index >= 0);
    try testing.expect(result_count > 0);

    const result_text = try text_page.getText(testing.allocator, result_index, result_count);
    defer testing.allocator.free(result_text);
    const result_utf8 = try std.unicode.utf16LeToUtf8Alloc(testing.allocator, result_text);
    defer testing.allocator.free(result_utf8);
    try testing.expectEqualStrings("Introduction", result_utf8);

    // Should not find a second occurrence
    try testing.expect(!search_handle.findNext());
}

test "getText" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();
    const page = try test_pdf.loadPage(0);
    defer page.deinit();

    const text_page = try page.loadTextPage();
    defer text_page.deinit();

    // Get all text from the page
    const text = try text_page.getText(testing.allocator, 0, null);
    defer testing.allocator.free(text);

    log.info("getText returned {d} UTF-16 characters", .{text.len});

    const utf8_text = try std.unicode.utf16LeToUtf8Alloc(testing.allocator, text);
    defer testing.allocator.free(utf8_text);

    log.info("Converted to UTF-8: '{s}'", .{utf8_text});

    // Should contain some text
    try testing.expect(utf8_text.len > 0);

    // Should contain "Introduction" somewhere in the text
    try testing.expect(std.mem.find(u8, utf8_text, "Introduction") != null);

    // Test getting a specific range
    const partial_text = try text_page.getText(testing.allocator, 0, 20);
    defer testing.allocator.free(partial_text);

    const partial_utf8 = try std.unicode.utf16LeToUtf8Alloc(testing.allocator, partial_text);
    defer testing.allocator.free(partial_utf8);

    // Partial text should be shorter than full text
    try testing.expect(partial_utf8.len <= utf8_text.len);
}

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

/// An annotation's flags, from the `FPDF_ANNOT_FLAG_*` defines in fpdf_annot.h
/// (PDF Reference 6th edition, table 8.16).
///
/// `hidden` and `noview` are the two that matter to a viewer: pdfium paints
/// neither, so a consumer walking annotations for their text should skip them
/// rather than surface content the page does not show.
pub const AnnotationFlags = packed struct {
    invisible: bool = false,
    hidden: bool = false,
    print: bool = false,
    nozoom: bool = false,

    norotate: bool = false,
    noview: bool = false,
    readonly: bool = false,
    locked: bool = false,

    togglenoview: bool = false,
    _padding_1: u7 = 0,

    _padding_2: u16 = 0,
};

comptime {
    assert(@sizeOf(AnnotationFlags) == @sizeOf(c_int));
    assert(@as(c_int, @bitCast(AnnotationFlags{})) == c.FPDF_ANNOT_FLAG_NONE);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .invisible = true })) == c.FPDF_ANNOT_FLAG_INVISIBLE);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .hidden = true })) == c.FPDF_ANNOT_FLAG_HIDDEN);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .print = true })) == c.FPDF_ANNOT_FLAG_PRINT);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .nozoom = true })) == c.FPDF_ANNOT_FLAG_NOZOOM);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .norotate = true })) == c.FPDF_ANNOT_FLAG_NOROTATE);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .noview = true })) == c.FPDF_ANNOT_FLAG_NOVIEW);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .readonly = true })) == c.FPDF_ANNOT_FLAG_READONLY);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .locked = true })) == c.FPDF_ANNOT_FLAG_LOCKED);
    assert(@as(c_int, @bitCast(AnnotationFlags{ .togglenoview = true })) == c.FPDF_ANNOT_FLAG_TOGGLENOVIEW);
}

/// The kind of an interactive form field, from the `FPDF_FORMFIELD_*` defines
/// in fpdf_formfill.h.
///
/// pdfium builds with XFA enabled can additionally return values 8-15 for XFA
/// fields; the vendored binaries are built without XFA, and
/// `Annotation.getFormFieldType` reports anything outside this set (including
/// pdfium's -1 error return) as `error.Failed`.
pub const FormFieldType = enum(c_int) {
    unknown = c.FPDF_FORMFIELD_UNKNOWN,
    push_button = c.FPDF_FORMFIELD_PUSHBUTTON,
    checkbox = c.FPDF_FORMFIELD_CHECKBOX,
    radio_button = c.FPDF_FORMFIELD_RADIOBUTTON,
    combo_box = c.FPDF_FORMFIELD_COMBOBOX,
    list_box = c.FPDF_FORMFIELD_LISTBOX,
    text_field = c.FPDF_FORMFIELD_TEXTFIELD,
    signature = c.FPDF_FORMFIELD_SIGNATURE,
};

/// The `/Ff` field flags of a form field, from the `FPDF_FORMFLAG_*` defines.
/// The `text_*` bits are only meaningful for text fields and the `choice_*`
/// bits only for combo and list boxes.
pub const FormFieldFlags = packed struct(c_int) {
    readonly: bool = false,
    required: bool = false,
    noexport: bool = false,
    _padding_1: u9 = 0,

    text_multiline: bool = false,
    text_password: bool = false,
    _padding_2: u3 = 0,

    choice_combo: bool = false,
    choice_edit: bool = false,
    _padding_3: u2 = 0,

    choice_multi_select: bool = false,
    _padding_4: u10 = 0,
};

comptime {
    assert(@sizeOf(FormFieldFlags) == @sizeOf(c_int));
    assert(@as(c_int, @bitCast(FormFieldFlags{})) == c.FPDF_FORMFLAG_NONE);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .readonly = true })) == c.FPDF_FORMFLAG_READONLY);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .required = true })) == c.FPDF_FORMFLAG_REQUIRED);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .noexport = true })) == c.FPDF_FORMFLAG_NOEXPORT);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .text_multiline = true })) == c.FPDF_FORMFLAG_TEXT_MULTILINE);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .text_password = true })) == c.FPDF_FORMFLAG_TEXT_PASSWORD);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .choice_combo = true })) == c.FPDF_FORMFLAG_CHOICE_COMBO);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .choice_edit = true })) == c.FPDF_FORMFLAG_CHOICE_EDIT);
    assert(@as(c_int, @bitCast(FormFieldFlags{ .choice_multi_select = true })) == c.FPDF_FORMFLAG_CHOICE_MULTI_SELECT);
}

/// pdfium's two-call UTF-16LE string convention, shared by every form-field
/// string getter: call once with a null buffer to learn the length in *bytes*
/// including the two-byte NUL, allocate, call again, then drop the NUL and
/// transcode.
///
/// `getter` is any pdfium function whose last two parameters are
/// `(FPDF_WCHAR* buffer, unsigned long buflen)`; `leading_args` is a tuple of
/// everything before them.
///
/// Returns an empty string for pdfium's two "nothing here" answers: 0 (error
/// or absent) and 2 (an empty string, i.e. just the NUL).
fn getUtf16StringAsUtf8(
    allocator: std.mem.Allocator,
    getter: anytype,
    leading_args: anytype,
) ![]u8 {
    const null_buffer: [*c]u16 = null;
    const byte_len: usize = @intCast(@call(.auto, getter, leading_args ++ .{ null_buffer, @as(c_ulong, 0) }));
    if (byte_len < 4) return allocator.dupe(u8, "");

    const buffer = try allocator.alloc(u16, byte_len / 2);
    defer allocator.free(buffer);

    const check = @call(.auto, getter, leading_args ++ .{
        @as([*c]u16, @ptrCast(buffer.ptr)),
        @as(c_ulong, @intCast(buffer.len * 2)),
    });
    if (check != byte_len) {
        log.err("pdfium string getter returned {d} but expected {d}", .{ check, byte_len });
        return error.Failed;
    }

    return std.unicode.utf16LeToUtf8Alloc(allocator, buffer[0 .. buffer.len - 1]);
}

pub const Annotation = opaque {
    pub fn deinit(self: *Annotation) void {
        FPDFPage_CloseAnnot(@ptrCast(self));
    }

    pub fn getSubtype(self: *Annotation) AnnotationSubtype {
        return @enumFromInt(FPDFAnnot_GetSubtype(@ptrCast(self)));
    }

    /// This annotation's flags. Requires `HAS_FORM_API` (see the declaration of
    /// `FPDFAnnot_GetFlags`); reports all-clear when the symbol is unavailable,
    /// which is the same answer pdfium gives for a flagless annotation.
    pub fn getFlags(self: *Annotation) AnnotationFlags {
        if (!HAS_FORM_API) return .{};
        return @bitCast(FPDFAnnot_GetFlags(@ptrCast(self)));
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

    // Form field accessors. All of these are only meaningful for annotations
    // whose `getSubtype()` is `.widget`, and all require a live `FormHandle`
    // for the document the annotation came from.

    pub fn getFormFieldType(self: *Annotation, form_handle: *FormHandle) !FormFieldType {
        const raw = FPDFAnnot_GetFormFieldType(@ptrCast(form_handle), @ptrCast(self));
        return std.enums.fromInt(FormFieldType, raw) orelse {
            log.err("FPDFAnnot_GetFormFieldType returned unexpected value {d}", .{raw});
            return error.Failed;
        };
    }

    /// The fully-qualified field name (`/T`, joined with any ancestors'). Every
    /// widget of a radio group, and every kid widget of a field split across
    /// pages, reports the same name — dedupe on it if you are summarising a
    /// document's fields.
    ///
    /// Empty when the field has no name. Caller owns the result.
    pub fn getFormFieldNameUtf8(self: *Annotation, form_handle: *FormHandle, allocator: std.mem.Allocator) ![]u8 {
        return getUtf16StringAsUtf8(allocator, FPDFAnnot_GetFormFieldName, .{
            @as(c.FPDF_FORMHANDLE, @ptrCast(form_handle)),
            @as(c.FPDF_ANNOTATION, @ptrCast(self)),
        });
    }

    /// The field's alternate name (`/TU`), the human-readable label a viewer
    /// shows as a tooltip. Empty when absent. Caller owns the result.
    pub fn getFormFieldAlternateNameUtf8(self: *Annotation, form_handle: *FormHandle, allocator: std.mem.Allocator) ![]u8 {
        return getUtf16StringAsUtf8(allocator, FPDFAnnot_GetFormFieldAlternateName, .{
            @as(c.FPDF_FORMHANDLE, @ptrCast(form_handle)),
            @as(c.FPDF_ANNOTATION, @ptrCast(self)),
        });
    }

    /// The field's value (`/V`). For checkboxes and radio buttons this is the
    /// *field's* state, not this widget's — use `isChecked` plus
    /// `getFormFieldExportValueUtf8` for those. Caller owns the result.
    pub fn getFormFieldValueUtf8(self: *Annotation, form_handle: *FormHandle, allocator: std.mem.Allocator) ![]u8 {
        return getUtf16StringAsUtf8(allocator, FPDFAnnot_GetFormFieldValue, .{
            @as(c.FPDF_FORMHANDLE, @ptrCast(form_handle)),
            @as(c.FPDF_ANNOTATION, @ptrCast(self)),
        });
    }

    /// The "on" state name of a checkbox or radio button widget — what `/V`
    /// holds when this particular widget is the checked one. Empty for other
    /// field kinds. Caller owns the result.
    pub fn getFormFieldExportValueUtf8(self: *Annotation, form_handle: *FormHandle, allocator: std.mem.Allocator) ![]u8 {
        return getUtf16StringAsUtf8(allocator, FPDFAnnot_GetFormFieldExportValue, .{
            @as(c.FPDF_FORMHANDLE, @ptrCast(form_handle)),
            @as(c.FPDF_ANNOTATION, @ptrCast(self)),
        });
    }

    pub fn getFormFieldFlags(self: *Annotation, form_handle: *FormHandle) !FormFieldFlags {
        const raw = FPDFAnnot_GetFormFieldFlags(@ptrCast(form_handle), @ptrCast(self));
        if (raw < 0) return error.Failed;
        return @bitCast(raw);
    }

    /// Whether this checkbox or radio button widget is the checked one. False
    /// for every other field kind.
    pub fn isChecked(self: *Annotation, form_handle: *FormHandle) bool {
        return FPDFAnnot_IsChecked(@ptrCast(form_handle), @ptrCast(self)) != 0;
    }

    /// The number of entries in a combo or list box's `/Opt` array.
    pub fn getOptionCount(self: *Annotation, form_handle: *FormHandle) !usize {
        const count = FPDFAnnot_GetOptionCount(@ptrCast(form_handle), @ptrCast(self));
        if (count < 0) return error.Failed;
        return @intCast(count);
    }

    /// The label of the option at `index` in a combo or list box. Caller owns
    /// the result.
    pub fn getOptionLabelUtf8(
        self: *Annotation,
        form_handle: *FormHandle,
        index: usize,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        return getUtf16StringAsUtf8(allocator, FPDFAnnot_GetOptionLabel, .{
            @as(c.FPDF_FORMHANDLE, @ptrCast(form_handle)),
            @as(c.FPDF_ANNOTATION, @ptrCast(self)),
            @as(c_int, @intCast(index)),
        });
    }

    /// Whether the option at `index` is selected. A list box may have several.
    pub fn isOptionSelected(self: *Annotation, form_handle: *FormHandle, index: usize) bool {
        return FPDFAnnot_IsOptionSelected(@ptrCast(form_handle), @ptrCast(self), @intCast(index)) != 0;
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

    pub fn getTitleUtf16(self: *Bookmark, allocator: std.mem.Allocator) ![]u16 {
        const len: usize = @intCast(FPDFBookmark_GetTitle(@ptrCast(self), null, 0));
        const buffer = try allocator.alloc(u16, len / 2);
        const check = FPDFBookmark_GetTitle(@ptrCast(self), @ptrCast(buffer.ptr), @intCast(len));

        if (builtin.mode == .Debug) {
            // Sanity checks that pdfium works as documented.
            if (check != len) {
                log.err("FPDFBookmark_GetTitle returned {d} but expected {d}", .{ check, len });
                return error.Failed;
            }

            if (buffer.len > 0 and buffer[buffer.len - 1] != 0) {
                log.warn("Unexpected behaviour: pdfium response was not terminated with UTF-16 NUL character", .{});
                return error.Failed;
            }
        }

        return buffer;
    }

    pub fn getTitleUtf8(self: *Bookmark, allocator: std.mem.Allocator) ![]u8 {
        const utf16_title = try self.getTitleUtf16(allocator);
        defer allocator.free(utf16_title);
        if (utf16_title.len > 1) {
            const utf16_data = utf16_title[0 .. utf16_title.len - 1];
            return try std.unicode.utf16LeToUtf8Alloc(allocator, utf16_data);
        } else {
            return try allocator.dupe(u8, "");
        }
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

    pub fn find(document: *Document, allocator: std.mem.Allocator, title: []const u8) ?*Bookmark {
        const utf16_title = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch {
            return null;
        };
        defer allocator.free(utf16_title);

        if (FPDFBookmark_Find(@ptrCast(document), @ptrCast(utf16_title.ptr))) |bookmark| {
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

test "getTitleUtf16" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();

    const bm = test_pdf.getFirstBookmark();
    const title = try bm.?.getTitleUtf16(testing.allocator);
    defer testing.allocator.free(title);

    try testing.expect(title.len > 0);
    const u8Title = try std.unicode.utf16LeToUtf8AllocZ(testing.allocator, title);
    defer testing.allocator.free(u8Title);
    try testing.expectEqualStrings("Introduction\x00", u8Title);
}

test "getTitleUtf8" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();

    const bm = test_pdf.getFirstBookmark();
    const title = try bm.?.getTitleUtf8(testing.allocator);
    defer testing.allocator.free(title);

    try testing.expect(title.len > 0);
    try testing.expectEqualStrings("Introduction", title);
}

test "find bookmark" {
    const test_pdf = try Document.load("test/test.pdf");
    defer test_pdf.deinit();

    const found_bookmark = Bookmark.find(test_pdf, testing.allocator, "Introduction");
    try testing.expect(found_bookmark != null);

    const title = try found_bookmark.?.getTitleUtf8(testing.allocator);
    defer testing.allocator.free(title);

    try testing.expectEqualStrings("Introduction", title);
}

// The form-field fixture. Regenerate with `python3 test/gen_form.py`; see that
// script for what it contains.
const TEST_FORM_PDF = "test/form.pdf";

/// Everything `form_fields.zig`-style extraction needs from one widget annot,
/// flattened so the tests can assert on it as data. Allocated into an arena by
/// `TEST_collectFormFields`.
const TEST_FormField = struct {
    kind: FormFieldType,
    name: []const u8,
    label: []const u8,
    value: []const u8,
    export_value: []const u8,
    flags: FormFieldFlags,
    checked: bool,
};

fn TEST_collectFormFields(
    arena: std.mem.Allocator,
    page: *Page,
    form_handle: *FormHandle,
) ![]TEST_FormField {
    var fields: std.ArrayList(TEST_FormField) = .empty;
    for (0..page.getAnnotationCount()) |i| {
        const annot = try page.getAnnotation(i);
        defer annot.deinit();
        if (annot.getSubtype() != .widget) continue;

        try fields.append(arena, .{
            .kind = try annot.getFormFieldType(form_handle),
            .name = try annot.getFormFieldNameUtf8(form_handle, arena),
            .label = try annot.getFormFieldAlternateNameUtf8(form_handle, arena),
            .value = try annot.getFormFieldValueUtf8(form_handle, arena),
            .export_value = try annot.getFormFieldExportValueUtf8(form_handle, arena),
            .flags = try annot.getFormFieldFlags(form_handle),
            .checked = annot.isChecked(form_handle),
        });
    }
    return fields.toOwnedSlice(arena);
}

test "form: getFormType" {
    const no_form = try Document.load("test/test.pdf");
    defer no_form.deinit();
    try testing.expectEqual(FormType.none, no_form.getFormType());

    const form = try Document.load(TEST_FORM_PDF);
    defer form.deinit();
    try testing.expectEqual(FormType.acro_form, form.getFormType());
}

test "form: field metadata" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    // A local is fine here only because it outlives the handle within this
    // function; a real caller has to keep it somewhere with a stable address.
    var info = defaultFormFillInfo();
    const form_handle = doc.initFormFillEnv(&info).?;
    defer form_handle.deinit();

    const page = try doc.loadPage(0);
    page.formOnAfterLoad(form_handle);
    defer {
        page.formOnBeforeClose(form_handle);
        page.deinit();
    }

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const fields = try TEST_collectFormFields(arena, page, form_handle);

    // Three of these are the one radio group: every button in a group is its
    // own widget annotation, all sharing the field name. The last is hidden —
    // still a field, and still enumerated here; see "form: annotation flags".
    try testing.expectEqual(@as(usize, 11), fields.len);

    try testing.expectEqual(FormFieldType.text_field, fields[0].kind);
    try testing.expectEqualStrings("full_name", fields[0].name);
    try testing.expectEqualStrings("Full name", fields[0].label);
    try testing.expectEqualStrings("Ada Lovelace", fields[0].value);
    try testing.expectEqual(false, fields[0].flags.readonly);

    // An empty value comes back as "", not as an error.
    try testing.expectEqualStrings("email", fields[1].name);
    try testing.expectEqualStrings("", fields[1].value);

    try testing.expectEqualStrings("account_id", fields[2].name);
    try testing.expectEqualStrings("ENO-00042", fields[2].value);
    try testing.expectEqual(true, fields[2].flags.readonly);

    try testing.expectEqual(FormFieldType.checkbox, fields[3].kind);
    try testing.expectEqualStrings("agree_terms", fields[3].name);
    try testing.expectEqual(true, fields[3].checked);
    try testing.expectEqualStrings("Yes", fields[3].export_value);

    try testing.expectEqual(FormFieldType.checkbox, fields[4].kind);
    try testing.expectEqualStrings("subscribe", fields[4].name);
    try testing.expectEqual(false, fields[4].checked);

    // The radio group: same name on all three, exactly one checked, and the
    // export value is what distinguishes them.
    var checked_count: usize = 0;
    var checked_export: []const u8 = "";
    for (fields[5..8]) |field| {
        try testing.expectEqual(FormFieldType.radio_button, field.kind);
        try testing.expectEqualStrings("plan", field.name);
        if (field.checked) {
            checked_count += 1;
            checked_export = field.export_value;
        }
    }
    try testing.expectEqual(@as(usize, 1), checked_count);
    try testing.expectEqualStrings("pro", checked_export);

    try testing.expectEqual(FormFieldType.combo_box, fields[8].kind);
    try testing.expectEqualStrings("country", fields[8].name);
    try testing.expectEqualStrings("Canada", fields[8].value);
    try testing.expectEqual(true, fields[8].flags.choice_combo);

    try testing.expectEqual(FormFieldType.list_box, fields[9].kind);
    try testing.expectEqualStrings("languages", fields[9].name);
    try testing.expectEqual(true, fields[9].flags.choice_multi_select);
}

test "form: annotation flags distinguish a hidden field" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    const page = try doc.loadPage(0);
    defer page.deinit();

    // `internal_ref` is the last widget in the fixture and the only hidden one.
    // Note this needs no form handle: annotation flags are a property of the
    // annotation, not of the form field.
    var visible: usize = 0;
    var hidden: usize = 0;
    for (0..page.getAnnotationCount()) |i| {
        const annot = try page.getAnnotation(i);
        defer annot.deinit();
        if (annot.getSubtype() != .widget) continue;

        const flags = annot.getFlags();
        if (flags.hidden) {
            hidden += 1;
            // The hidden one is hidden and nothing else; in particular pdfium
            // does not also mark it noview.
            try testing.expectEqual(false, flags.noview);
            try testing.expectEqual(false, flags.print);
        } else {
            visible += 1;
            try testing.expectEqual(true, flags.print);
        }
    }
    try testing.expectEqual(@as(usize, 1), hidden);
    try testing.expectEqual(@as(usize, 10), visible);
}

test "form: choice options" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    var info = defaultFormFillInfo();
    const form_handle = doc.initFormFillEnv(&info).?;
    defer form_handle.deinit();

    const page = try doc.loadPage(0);
    page.formOnAfterLoad(form_handle);
    defer {
        page.formOnBeforeClose(form_handle);
        page.deinit();
    }

    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // The combo box, at annot index 8, and the list box at 9.
    for ([_]struct { index: usize, expected: []const []const u8, selected: []const u8 }{
        .{ .index = 8, .expected = &.{ "Canada", "United States", "Mexico" }, .selected = "Canada" },
        .{ .index = 9, .expected = &.{ "Zig", "C", "Rust" }, .selected = "Zig" },
    }) |case| {
        const annot = try page.getAnnotation(case.index);
        defer annot.deinit();

        try testing.expectEqual(case.expected.len, try annot.getOptionCount(form_handle));

        var selected: []const u8 = "";
        for (case.expected, 0..) |expected_label, i| {
            const label = try annot.getOptionLabelUtf8(form_handle, i, arena);
            try testing.expectEqualStrings(expected_label, label);
            if (annot.isOptionSelected(form_handle, i)) selected = label;
        }
        try testing.expectEqualStrings(case.selected, selected);
    }
}

test "form: getFormFieldAnnotAtPoint" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    var info = defaultFormFillInfo();
    const form_handle = doc.initFormFillEnv(&info).?;
    defer form_handle.deinit();

    const page = try doc.loadPage(0);
    page.formOnAfterLoad(form_handle);
    defer {
        page.formOnBeforeClose(form_handle);
        page.deinit();
    }

    // The middle of full_name's rect, in PDF user space (bottom-left origin).
    const hit = page.getFormFieldAnnotAtPoint(form_handle, 172, 670).?;
    defer hit.deinit();

    const name = try hit.getFormFieldNameUtf8(form_handle, testing.allocator);
    defer testing.allocator.free(name);
    try testing.expectEqualStrings("full_name", name);

    // Empty margin, well clear of every widget.
    try testing.expectEqual(@as(?*Annotation, null), page.getFormFieldAnnotAtPoint(form_handle, 500, 100));
}

/// Render `page` at 1:1 into a fresh BGRA buffer, optionally drawing form
/// fields over it. Caller owns the buffer.
fn TEST_renderFormPage(allocator: std.mem.Allocator, page: *Page, form_handle: ?*FormHandle) ![]u8 {
    const width: c_int = @intFromFloat(@round(page.getWidth()));
    const height: c_int = @intFromFloat(@round(page.getHeight()));
    const stride = width * 4;

    const buffer = try allocator.alloc(u8, @intCast(height * stride));
    errdefer allocator.free(buffer);

    const bitmap = try Bitmap.initEx(width, height, .bgra, buffer, stride);
    defer bitmap.deinit();

    try bitmap.fillRect(0, 0, width, height, @bitCast(@as(c_ulong, 0xFFFFFFFF)));
    bitmap.renderPage(page, 0, 0, width, height, 0, .{ .annot = true });
    if (form_handle) |fh| {
        bitmap.drawFormFields(fh, page, 0, 0, width, height, 0, .{ .annot = true });
    }
    return buffer;
}

/// Count the non-white pixels of `buffer` inside a top-left-origin rect.
fn TEST_countNonWhite(buffer: []const u8, stride: usize, x: usize, y: usize, width: usize, height: usize) usize {
    var count: usize = 0;
    for (y..y + height) |row| {
        for (x..x + width) |col| {
            const px = buffer[row * stride + col * 4 ..][0..4];
            if (px[0] != 0xFF or px[1] != 0xFF or px[2] != 0xFF) count += 1;
        }
    }
    return count;
}

test "form: drawFormFields paints widgets renderPage does not" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    var info = defaultFormFillInfo();
    const form_handle = doc.initFormFillEnv(&info).?;
    defer form_handle.deinit();

    const page = try doc.loadPage(0);
    page.formOnAfterLoad(form_handle);
    defer {
        page.formOnBeforeClose(form_handle);
        page.deinit();
    }

    const stride: usize = @intFromFloat(@round(page.getWidth()) * 4);
    const page_height: usize = @intFromFloat(@round(page.getHeight()));

    // full_name's widget rect is (72, 660)-(272, 680) in PDF user space. Take
    // it inset by 4pt and flip Y against the page height for the
    // top-left-origin raster: the inset drops the field's *border*, which
    // reportlab draws into the page content stream and which therefore shows
    // up with or without a form environment. What is left inside is only the
    // widget's own appearance stream — the text "Ada Lovelace".
    const rect_x: usize = 76;
    const rect_y: usize = page_height - 676;
    const rect_w: usize = 192;
    const rect_h: usize = 12;

    // The negative case, and the whole reason this binding exists:
    // FPDF_RenderPageBitmap skips widget annotations even with FPDF_ANNOT, so
    // the value a user typed into the form is simply not there.
    {
        const buffer = try TEST_renderFormPage(testing.allocator, page, null);
        defer testing.allocator.free(buffer);
        try testing.expectEqual(
            @as(usize, 0),
            TEST_countNonWhite(buffer, stride, rect_x, rect_y, rect_w, rect_h),
        );
    }

    {
        const buffer = try TEST_renderFormPage(testing.allocator, page, form_handle);
        defer testing.allocator.free(buffer);
        try testing.expect(TEST_countNonWhite(buffer, stride, rect_x, rect_y, rect_w, rect_h) > 0);
    }
}

test "form: field highlight is opt-in" {
    const doc = try Document.load(TEST_FORM_PDF);
    defer doc.deinit();

    var info = defaultFormFillInfo();
    const form_handle = doc.initFormFillEnv(&info).?;
    defer form_handle.deinit();

    const page = try doc.loadPage(0);
    page.formOnAfterLoad(form_handle);
    defer {
        page.formOnBeforeClose(form_handle);
        page.deinit();
    }

    const stride: usize = @intFromFloat(@round(page.getWidth()) * 4);
    const page_height: usize = @intFromFloat(@round(page.getHeight()));
    // A point inside full_name's rect but clear of its text and border.
    const sample = (page_height - 675) * stride + 150 * 4;

    // Untouched by default: no highlight, so the field's background is the
    // page's white. A read-only viewer needs to do nothing to get this.
    {
        const buffer = try TEST_renderFormPage(testing.allocator, page, form_handle);
        defer testing.allocator.free(buffer);
        try testing.expectEqualSlices(u8, &.{ 0xFF, 0xFF, 0xFF }, buffer[sample..][0..3]);
    }

    // Setting a colour is what switches highlighting on. 0x000000FF is red,
    // *not* blue: the parameter is 0x00bbggrr, contrary to the header comment.
    {
        form_handle.setFieldHighlightColor(.unknown, 0x000000FF);
        form_handle.setFieldHighlightAlpha(255);
        const buffer = try TEST_renderFormPage(testing.allocator, page, form_handle);
        defer testing.allocator.free(buffer);
        // BGRA byte order.
        try testing.expectEqualSlices(u8, &.{ 0x00, 0x00, 0xFF }, buffer[sample..][0..3]);
    }
}

pub fn importPagesByIndex(
    dest_doc: *Document,
    src_doc: *Document,
    src_indices: []const usize,
    dest_index: usize,
) !void {
    const success = FPDF_ImportPagesByIndex(
        @ptrCast(dest_doc),
        @ptrCast(src_doc),
        @ptrCast(src_indices.ptr),
        @intCast(src_indices.len),
        @intCast(dest_index),
    );
    if (success == 0) {
        log.err(
            \\FPDF_ImportPagesByIndex failed. According to pdfium docs this means one 
            \\of the page_indices was invalid: {any}
        , .{src_indices});
        return error.InvalidIndex;
    }
}

test {
    _ = @import("ext/save.zig");
    _ = @import("ext/render.zig");
}

test "tests:beforeAll" {
    const bin_path = switch (builtin.os.tag) {
        .macos => "pdfium-binary/libpdfium.dylib",
        .linux => "pdfium-binary/libpdfium.so",
        else => unreachable,
    };

    bindPdfium(bin_path) catch |err| switch (err) {
        error.FileNotFound => {
            log.err("{s} not found. Please follow the instructions in the READ me to download it.", .{bin_path});
            return;
        },
        else => return err,
    };

    initLibrary();
}

test "tests:afterAll" {
    destroyLibrary();
}
