
# Getting pdfium
The easiest way to get started is to grab a prebuild pdfium binary from
https://github.com/bblanchon/pdfium-binaries

And drop it in vendor/

# Structure

`ext/` contains code that extends the pdfium library for convenience. The
goal is to only provide extensions in extremely obvious cases - like
saving files.
