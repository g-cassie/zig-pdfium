
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