# IMPORTANT
The library is currently working with zig 0.16.0. You must add `use_llvm = true`
when importing this library. Otherwise the self-hosted x86_64 backend — which is
the default in Debug mode — fails to resolve the pdfium symbols that are bound at
runtime via `std.DynLib`. On zig 0.15 this showed up as a link-time crash about
undefined symbols; on 0.16 it compiles and then segfaults at runtime instead.

Verified still broken by testing against zig 0.16.0 directly: dropping `use_llvm`
makes `zig build test` segfault.

The original report is https://github.com/ziglang/zig/issues/25151 (filed from this
repo's `zig-15` branch). Note that zig development has since **moved to Codeberg** —
the GitHub tracker is frozen, so that issue being "open" there is not a live signal,
and it does not appear to have been carried over (no issue on
https://codeberg.org/ziglang/zig mentions pdfium). Getting this fixed upstream would
mean re-filing it on Codeberg against a current zig.

# Getting pdfium
To use zig-pdfium you will need a prebuilt binary of the pdfium library from 
https://github.com/bblanchon/pdfium-binaries

Choose a release that corresponds to a folder in `include/*` (for example 7125).

Extract libpdfium.dylib and place it in `pdfium-binary/` folder. If you are not
on a Mac, place the appopriate file and update the bottom of `root.zig` to branch for 
your OS and use the correct path.

# Philosophy

`zig-pdfium` aims to be purely a ziggified version of the raw pdfium C API. 
Any additional should likely not be part of this library. Where it makes
overwhelming sense to do more than simply wrap the C API, that code should
go in the `ext/` folder.  The goal is to only provide extensions in extremely
obvious cases - like saving files.