module photog.color;

import ldc.attributes : fastmath;
import mir.ndslice : Slice, sliced, SliceKind;

import photog.utils;

// dfmt off
/**
RGB working spaces.
*/
enum WorkingSpace
{
    sRgb = "sRgb"
}

/**
Color space conversion matrices.
*/
private static immutable
{
    
    auto sRgbRgb2Xyz = [
        0.4124564, 0.3575761, 0.1804375,
        0.2126729, 0.7151522, 0.0721750,
        0.0193339, 0.1191920, 0.9503041
    ];

    auto sRgbRgb2XyzReverse = [
        0.1804375, 0.3575761, 0.4124564,
        0.0721750, 0.7151522, 0.2126729,
        0.9503041, 0.1191920, 0.0193339,
    ];
	
	auto sRgbXyz2Rgb = [
        3.2404542, -1.5371385, -0.4985314,
		-0.9692660, 1.8760108, 0.0415560,
		0.0556434, -0.2040259, 1.0572252
    ];
}

/**
Standard illuminants.
*/
enum Illuminant
{
    d65 = [0.95047, 1.0, 1.08883]
}

/**
Chromatic adaptation methods.
*/
enum ChromAdaptMethod
{
    bradford = "bradford"
}

/**
Chromatic adaptation method matrices.
*/
private static immutable
{
    auto bradfordXyz2Lms = [
        0.8951, 0.2664, -0.1614,
        -0.7502, 1.7135, 0.0367,
        0.0389, -0.0685, 1.0296
    ];
    
    auto bradfordInvXyz2Lms = [
        0.9869929, -0.1470543, 0.1599627,
        0.4323053, 0.5183603, 0.0492912,
        -0.0085287, 0.0400428, 0.9684867
    ];
}
// dfmt on

/**
Convert RGB input to XYZ.
*/
Slice!(ReturnType*, 3) rgb2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double,
        T)(Slice!(T, 3) input)
{
    return rgbBgr2Xyz!(false, workingSpace, ReturnType)(input);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    Slice!(double*, 3) rgb = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(rgb.rgb2Xyz, xyz));
}

/**
Convert BGR input to XYZ.
*/
Slice!(ReturnType*, 3) bgr2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double,
        T)(Slice!(T, 3) input)
{
    return rgbBgr2Xyz!(true, workingSpace, ReturnType)(input);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    Slice!(double*, 3) bgr = [
        0.0, 0.0, 1.0,
        0.0, 1.0, 0.0,
        1.0, 0.0, 0.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(bgr.bgr2Xyz, xyz));
}

private Slice!(ReturnType*, 3) rgbBgr2Xyz(bool isBgr, WorkingSpace workingSpace, ReturnType, T)(
        Slice!(T, 3) input)
in
{
    import std.traits : isFloatingPoint;

    static assert(isFloatingPoint!ReturnType, "Return type must be floating point.");
    assert(input.shape[2] == 3, "Input requires 3 channels.");
}
do
{
    import mir.ndslice : each, uninitSlice, zip;

    auto output = uninitSlice!ReturnType(input.shape);
    auto inputPack = pixelPack!3(input);
    auto outputPack = pixelPack!3(output);
    auto pixelZip = zip(inputPack, outputPack);

    static if (isBgr)
        auto conversionMatrix = mixin(workingSpace ~ "Rgb2XyzReverse").sliced(3, 3);
    else
        auto conversionMatrix = mixin(workingSpace ~ "Rgb2Xyz").sliced(3, 3);

    pixelZip.each!((z) {
        z.rgbBgr2XyzImpl!(isBgr, workingSpace)(conversionMatrix);
    });

    return output;
}

@fastmath void rgbBgr2XyzImpl(bool isBgr, WorkingSpace workingSpace, T, U)(
        T pixelZip, Slice!(U, 2) conversionMatrix)
{
    import kaleidic.lubeck : mtimes;
    import mir.ndslice : each;

    // pixelZip[0] = input
    // pixelZip[1] = output

    auto output = sliced(pixelZip[0].ptr, 3);

    // Linearize
    output.each!((ref chnl) {
        if (chnl <= 0.04045)
            chnl = chnl / 12.92;
        else
            chnl = ((chnl + 0.055) / 1.055) ^^ 2.4;
    });

    // Convert to XYZ
    output = conversionMatrix.mtimes(output);

    pixelZip[1][] = output.field;
}

/**
Convert XYZ input to RGB.
*/
Slice!(ReturnType*, 3) xyz2Rgb(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double,
        T)(Slice!(T, 3) input)
{
    return xyz2RgbBgr!(false, workingSpace, ReturnType)(input);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    Slice!(double*, 3) rgb = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(xyz.xyz2Rgb, rgb, 0.01, 1e-04));
}

/**
Convert XYZ input to BGR.
*/
Slice!(ReturnType*, 3) xyz2Bgr(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double,
        T)(Slice!(T, 3) input)
{
    return xyz2RgbBgr!(true, workingSpace, ReturnType)(input);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    Slice!(double*, 3) bgr = [
        0.0, 0.0, 1.0,
        0.0, 1.0, 0.0,
        1.0, 0.0, 0.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(xyz.xyz2Bgr, bgr, 0.01, 1e-04));
}

private Slice!(ReturnType*, 3) xyz2RgbBgr(bool isBgr, WorkingSpace workingSpace, ReturnType, T)(
        Slice!(T, 3) input)
in
{
    import std.traits : isFloatingPoint;

    static assert(isFloatingPoint!ReturnType, "Return type must be floating point.");
}
do
{
    import mir.ndslice : each, uninitSlice, zip;

    auto output = uninitSlice!ReturnType(input.shape);
    auto inputPack = pixelPack!3(input);
    auto outputPack = pixelPack!3(output);
    auto pixelZip = zip(inputPack, outputPack);
    auto conversionMatrix = mixin(workingSpace ~ "Xyz2Rgb").sliced(3, 3); // TODO: Known at compile-time. Send as template?
    pixelZip.each!((z) {
        z.xyz2RgbBgrImpl!(isBgr, workingSpace)(conversionMatrix);
    });
    // No need to unpack output. Underlying data has already been changed.
    return output;
}

@fastmath void xyz2RgbBgrImpl(bool isBgr, WorkingSpace workingSpace, T, U)(
        T pixelZip, Slice!(U, 2) conversionMatrix)
{
    import kaleidic.lubeck : mtimes;
    import mir.ndslice : each;

    // pixelZip[0] = input
    // pixelZip[1] = output

    // Convert to RGB
    // TODO: Is manual matrix math faster here?
    auto output = conversionMatrix.mtimes(sliced(pixelZip[0].ptr, 3));

    // Un-linearize
    output.each!((ref chnl) {
        if (chnl <= 0.0031308)
            chnl = chnl * 12.92;
        else
            chnl = (1.055 * chnl ^^ (1 / 2.4)) - 0.055;
    });

    static if (isBgr)
    {
        pixelZip[1][] = [output.field[2], output.field[1], output.field[0]];
    }
    else
    {
        pixelZip[1][] = output.field;
    }
}

/**
Chromatically adapt RGB input from the given source illuminant to the 
given destination illuminant.
*/
Slice!(Iterator, 3) chromAdapt(ChromAdaptMethod method = ChromAdaptMethod.bradford, Iterator)(
        Slice!(Iterator, 3) input,
        double[] srcIlluminant, double[] destIlluminant,
        WorkingSpace workingSpace = WorkingSpace.sRgb)
in
{
    import std.traits : isFloatingPoint;

    static assert(isFloatingPoint!(IteratorType!Iterator), "Input values must be floating point.");
    assert(srcIlluminant.length == 3);
    assert(destIlluminant.length == 3);
}
do
{
    import kaleidic.lubeck : mtimes;
    import mir.ndslice : diagonal, reshape, slice;

    auto xyz2Lms = mixin(method ~ "Xyz2Lms");
    auto lms2Xyz = mixin(method ~ "InvXyz2Lms");

    auto lmsSrc = xyz2Lms.sliced(3, 3).mtimes(srcIlluminant.sliced(3, 1));

    auto lmsDest = xyz2Lms.sliced(3, 3).mtimes(destIlluminant.sliced(3, 1));

    int err;
    auto lmsGain = slice!double([3, 3], 0);
    auto diag = lmsGain.diagonal;
    diag[] = (lmsDest / lmsSrc).reshape([3], err);
    assert(err == 0);

    auto transform = lms2Xyz.sliced(3, 3).mtimes(lmsGain).mtimes(xyz2Lms.sliced(3, 3));

    return input.rgb2Xyz.pixelMap!(pixel => transform.mtimes(pixel)).xyz2Rgb;
}

unittest
{
    import mir.ndslice : reshape, slice;

    // dfmt off
    ubyte[] uImage = [
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        120, 120, 120
    ];

    auto image = uImage.toFloating(1, 4);

    int err;
    double[] srcIlluminant = image
        .imageMean
        .reshape([1, 1, 3], err) // TODO: Get rid of the need for reshaping.
        .rgb2Xyz
        .field;
    assert(err == 0);
    //dfmt on

    auto ca = chromAdapt(image, srcIlluminant, Illuminant.d65);
    // TODO: Add assertion on chromAdapt output.
}
