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
	
	auto sRgbXyz2Rgb = [
        3.2404542, -1.5371385, -0.4985314,
		-0.9692660, 1.8760108, 0.0415560,
		0.0556434, -0.2040259, 1.0572252
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
Slice!(ReturnType*, 3) rgb2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, Iterator)(Slice!(Iterator, 3) input)
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

Params:
	workingSpace = working space of input image. Determines reference white. Defaults to sRGB (D65).
	ReturnType = element type for return slice. Determines output buffer type. Must be floating point. Defaults to double.
	input = Input image with 3 channels represented as B, G, and R respectively in that order.
	output = buffer where converted image will be copied. Reallocated if shape does not match input. Defaults to empty slice.

Returns:
	Returns XYZ version of the BGR input image.
*/
Slice!(ReturnType*, 3) bgr2Xyz(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, Iterator)(Slice!(Iterator, 3) input)
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

private Slice!(ReturnType*, 3) rgbBgr2Xyz(bool isBgr, WorkingSpace workingSpace, ReturnType, Iterator)(Slice!(Iterator, 3) input)
in
{
    import std.traits : isFloatingPoint;

    static assert(isFloatingPoint!ReturnType, "Return type must be floating point.");
    assert(input.shape[2] == 3, "Input requires 3 channels.");
}
do
{
	import kaleidic.lubeck : mtimes;
    import mir.ndslice : as, fuse, map, pack, reversed, uninitSlice;

    static if (isBgr)
    {
        auto convMatrix = mixin(workingSpace ~ "Rgb2Xyz").sliced(3, 3).reversed!1;
    }
    else
    {
        auto convMatrix = mixin(workingSpace ~ "Rgb2Xyz").sliced(3, 3);
    }
	// TODO: Try reshaping to a vector of pixels and then at end restoring shape. Should be easy as pie to compute on.
    auto output = uninitSlice!ReturnType(input.shape);

    // dfmt off
    output = input
        // convert input array elements
        .as!ReturnType
        // sRGB inverse compand (linearize with respect to energy)
        .map!(chnl => chnl <= 0.04045 ? chnl / 12.92 : ((chnl + 0.055) / 1.055) ^^ 2.4)
        // linear RGB to XYZ
		// pack the 3rd dimension (last 1 dimensions). mxn slice of 3x1 (pixel) slices.
		.pack!1
        // dot product of each pixel with conversion matrix
        .map!(pixel => convMatrix.mtimes(pixel))
        // join iterator values into a matrix
        .fuse;
    // dfmt on

    return output;
}

Slice!(ReturnType*, 3) xyz2Rgb(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, Iterator)(Slice!(Iterator, 3) input)
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

Slice!(ReturnType*, 3) xyz2Bgr(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, Iterator)(Slice!(Iterator, 3) input)
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

private Slice!(ReturnType*, 3) xyz2RgbBgr(bool isBgr, WorkingSpace workingSpace, ReturnType, Iterator)(Slice!(Iterator, 3) input)
in
{
    import std.traits : isFloatingPoint, isUnsigned;

    static assert(isFloatingPoint!ReturnType, "Return type must be floating point.");
    assert(input.shape[2] == 3, "Input requires 3 channels.");
}
do
{
	import mir.ndslice : each, pack, uninitSlice, zip;

    auto output = uninitSlice!ReturnType(input.shape);

	// Much easier to pack before zipping but we lose references in tuples.
	auto inputOutput = zip!true(input, output).pack!1;
	
	inputOutput.each!((io) {io.xyz2RgbBgrImpl!(isBgr, workingSpace);});

    return output;
}

void xyz2RgbBgrImpl(bool isBgr, WorkingSpace workingSpace, zipppedType)(zipppedType zipped)
{
	import kaleidic.lubeck : mtimes;
	import mir.ndslice : each, reversed;
	
	auto convMatrix = mixin(workingSpace ~ "Xyz2Rgb").sliced(3, 3);
	
	// Forced to use this structure because 1, we can't pack before zipping and keep references
	// and 2, mtimes does not accept RefTuple members directly.
	auto input = [zipped[0][0].__value(), zipped[1][0].__value(), zipped[2][0].__value()].sliced(3);
	
	auto output = convMatrix.mtimes(input);
	
	output.each!((ref chnl) 
	{
		if (chnl <= 0.0031308)
			chnl = chnl * 12.92;
		else
			chnl = (1.055 * chnl ^^ (1 / 2.4)) - 0.055;
	});
	
	static if (isBgr)
	{
		zipped[0][1].__value() = output[2];
		zipped[1][1].__value() = output[1];
		zipped[2][1].__value() = output[0];
	}
	else
	{
		zipped[0][1].__value() = output[0];
		zipped[1][1].__value() = output[1];
		zipped[2][1].__value() = output[2];
	}
}

/**
Clip the input to the range provided.
*/
T clip(double low, double high, T)(T value)
in
{
	import std.traits : isFloatingPoint;
	
	static assert(isFloatingPoint!T, "Value to clip must be floating point.");
	static assert(low >= -T.max);
	static assert(high <= T.max);
}
do
{
	if (value >= high)
		return high;
	else if (value <= low)
		return low;
	else
		return value;
}

/**
Grabs iterator type at compile-time.
*/
private template IteratorType(Iterator)
{
	import std.traits : Unqual;
	
	alias T = Unqual!(typeof(Iterator.init[0]));
	alias IteratorType = T;
}

unittest
{
	import mir.ndslice : slice;
	
	alias ExpectedType = long;
	
	void testIteratorType(Iterator)(Slice!(Iterator, 3) testSlice)
	{
		assert(is(IteratorType!Iterator == ExpectedType));
	}
	
	auto a = slice!(immutable(ExpectedType))([1, 2, 3], 0);
	testIteratorType(a);
}

/**
Recursively determine dimensions of a Slice.
*/
size_t[] dimensions(T)(T arr, size_t[] dims = []) {
	import std.traits : isNumeric;
	
	static if (isNumeric!T)
		return dims;
	else
	{
		dims ~= arr.length;
		return dimensions(arr[0], dims);
	}
}

unittest
{
	import mir.ndslice : slice;

	size_t[3] expectedDims = [1, 2, 3];
	auto a = slice!double(expectedDims, 0);
	assert(a.dimensions == expectedDims);
}
