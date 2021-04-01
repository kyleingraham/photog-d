# photog
Computational photography in D.

## Available Functions
- Chromatic adaption (von Kries transform using Bradford method)
- XYZ/RGB conversions (sRGB working space)

## Examples
### Chromatic Adaptation
```d
import std.file : read, write;
import std.stdio : writeln;

import jpeg_turbod;
import mir.ndslice : reshape, sliced;

import photog.color : chromAdapt, Illuminant, rgb2Xyz;
import photog.utils : imageMean, toFloating, toUnsigned;

void main()
{
    // Decompress JPEG image to unsigned array.
    const auto jpegFile = "image-in.jpg";
    auto jpegInput = cast(ubyte[]) jpegFile.read;

    auto dc = new Decompressor();
    ubyte[] pixels;
    int width, height;
    bool decompressed = dc.decompress(jpegInput, pixels, width, height);

    if (!decompressed)
    {
        dc.errorInfo.writeln;
        return;
    }

    // Convert unsigned image array to floating point slice.
    auto image = pixels.sliced(height, width, 3).toFloating;

    // Use gray world approach to estimate source illuminant.
    int err;
    double[] srcIlluminant = image.imageMean.reshape([1, 1, 3], err).rgb2Xyz.field;
    assert(err == 0);

    // Chromatically adapt image to D65 illuminant.
    auto caImage = chromAdapt(image, srcIlluminant, Illuminant.d65).toUnsigned;

    // Compress image to JPEG file.
    auto c = new Compressor();
    ubyte[] jpegOutput;
    bool compressed = c.compress(caImage.field, jpegOutput, width, height, 90);

    if (!compressed)
    {
        c.errorInfo.writeln;
        return;
    }

    "image-out.jpg".write(jpegOutput);
}

```

API inspired by DCV (https://github.com/libmir/dcv).
