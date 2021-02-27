module photog.color;

import mir.ndslice : Slice, sliced;

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
    // dfmt off
    auto sRgbRgb2Xyz = [
        0.4124564, 0.3575761, 0.1804375,
        0.2126729, 0.7151522, 0.0721750,
        0.0193339, 0.1191920, 0.9503041
    ];
    // dfmt on
}

/**
Convert RGB input to XYZ.

Params:
	workingSpace = working space of input image. Determines reference white. Defaults to sRGB (D65).
	ReturnType = element type for return slice. Determines output buffer type. Must be floating point. Defaults to double.
	input = Input image with 3 channels represented as R, G, and B respectively in that order.
	output = buffer where converted image will be copied. Reallocated if shape does not match input. Defaults to empty slice.

Returns:
	Returns XYZ version of the RGB input image.
*/
Slice!(ReturnType*, 3) rgb2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb,
        ReturnType = double, InputType)(Slice!(InputType*, 3) input,
        Slice!(ReturnType*, 3) output = Slice!(ReturnType*, 3)())
{
    return rgbBgr2Xyz!(false, workingSpace, ReturnType, InputType)(input, output);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    ubyte[] rgb = [
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        120, 120, 120
    ];

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(rgb.sliced(4, 1, 3).rgb2Xyz, xyz));
}

/**
Convert BGR input to XYZ.

Params:
	workingSpace = working space of input image. Determines reference white. Defaults to sRGB (D65).
	ReturnType = element type for return slice. Determines output buffer type. Must be floating point. Defaults to double.
	input = Input image with 3 channels represented as B, G, and R respectively in that order.
	output = buffer where converted image will be copied. Reallocated if shape does not match input. Defaults to empty slice.

Returns:
	Returns XYZ version of the BGR input image.
*/
Slice!(ReturnType*, 3) bgr2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb,
        ReturnType = double, InputType)(Slice!(InputType*, 3) input,
        Slice!(ReturnType*, 3) output = Slice!(ReturnType*, 3)())
{
    return rgbBgr2Xyz!(true, workingSpace, ReturnType, InputType)(input, output);
}

unittest
{
    import std.math : approxEqual;

    // dfmt off
    ubyte[] bgr = [
        0, 0, 255,
        0, 255, 0,
        255, 0, 0,
        120, 120, 120
    ];

    Slice!(double*, 3) xyz = [
        0.412456, 0.212673, 0.019334,
        0.357576, 0.715152, 0.119192,
        0.180438, 0.072175, 0.950304,
        0.178518, 0.187821, 0.204505
    ].sliced(4, 1, 3);
    // dfmt on

    assert(approxEqual(bgr.sliced(4, 1, 3).bgr2Xyz, xyz));
}

private Slice!(ReturnType*, 3) rgbBgr2Xyz(bool isBgr, WorkingSpace workingSpace,
        ReturnType, InputType)(Slice!(InputType*, 3) input, Slice!(ReturnType*, 3) output)
in
{
    import std.traits : isFloatingPoint;

    static assert(isFloatingPoint!ReturnType, "Return type must be floating point.");
    assert(input.shape[2] == 3, "Input requires 3 channels.");
}
do
{
    import kaleidic.lubeck : mtimes;
    import mir.ndslice : as, byDim, fuse, map, reversed, uninitSlice;

    static if (isBgr)
    {
        auto convMatrix = mixin(workingSpace ~ "Rgb2Xyz").sliced(3, 3).reversed!1;
    }
    else
    {
        auto convMatrix = mixin(workingSpace ~ "Rgb2Xyz").sliced(3, 3);
    }

    if (input.shape != output.shape)
        output = uninitSlice!ReturnType(input.shape);

    // dfmt off
    output[] = input
        // convert input array elements
        .as!ReturnType
        // normalize pixel channels to range [0, 1]
        .map!(chnl => chnl / InputType.max)
        // sRGB inverse compand (linearize with respect to energy)
        .map!(chnl => chnl <= 0.04045 ? chnl / 12.92 : ((chnl + 0.055) / 1.055) ^^ 2.4)
        // linear RGB to XYZ
        // iterator by m and n over pixels (3rd dimension)
        .byDim!(0, 1)
        // dot product of each pixel with conversion matrix
        .map!(pixel => mtimes(convMatrix, pixel))
        // join iterator values into a matrix
        .fuse;
    // dfmt on

    return output;
}
