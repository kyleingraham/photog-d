module photog.color;

import ldc.attributes : fastmath;
import mir.ndslice : Slice, sliced, SliceKind;

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

Slice!(ReturnType*, 3) xyz2Rgb(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, T)(Slice!(T, 3) input)
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

Slice!(ReturnType*, 3) xyz2Bgr(WorkingSpace workingSpace = WorkingSpace.sRgb, ReturnType = double, T)(Slice!(T, 3) input)
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

/**
Convert [M, N, P] slice to [MxN] slice of [P] arrays.
*/
auto pixelPack(size_t chnls, InputType, size_t dims, SliceKind kind)(Slice!(InputType*, dims, kind) image)
in
{
    assert(dims == 3, "Image must have 3 dimensions.");
}
do
{
    // TODO: How to we specify strides? e.g. Slice!(ReturnType*, 1, kind)(shape, strides, iterator);
    size_t[1] shape = [image.shape[0] * image.shape[1]];
    alias ReturnType = InputType[chnls];
    ReturnType* iterator = cast(ReturnType*) image.iterator;
    return Slice!(ReturnType*, 1, kind)(shape, iterator);
}

unittest
{
    // dfmt off
    Slice!(double*, 3) rgb = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);
    // dfmt on

    auto packed = pixelPack!3(rgb);
    assert(packed.shape == [4 * 1]);
    assert(packed[0].length == 3);
}

/**
Convert [MxN] slice of [P] arrays to [M, N, P] slice.
*/
auto pixelUnpack(size_t chnls, InputType, size_t dims, SliceKind kind)(Slice!(InputType*, dims, kind) image, size_t height, size_t width)
in
{
    // TODO: Validate chnls * width * height == # of elements in array underlying image slice.
    assert(dims == 1, "Image must have 1 dimension.");
}
do
{
    size_t[3] shape = [height, width, chnls];
    alias ReturnType = IteratorType!InputType;
    ReturnType* iterator = cast(ReturnType*) image.iterator;
    return Slice!(ReturnType*, 3, kind)(shape, iterator);
}

unittest
{
    // dfmt off
    Slice!(double[]*, 1) rgb = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
        [0.470588, 0.470588, 0.470588]
    ].sliced(4);
    // dfmt on

    auto unpacked = pixelUnpack!3(rgb, 4, 1);
    assert(unpacked.shape == [4, 1, 3]);
    assert(unpacked[0][0].length == 3);
}

private Slice!(ReturnType*, 3) xyz2RgbBgr(bool isBgr, WorkingSpace workingSpace, ReturnType, T)(Slice!(T, 3) input)
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
    auto conversionMatrix = mixin(workingSpace ~ "Xyz2Rgb").sliced(3, 3); // TODO: Known at compile-time. Send as template?
    pixelZip.each!((z) {z.xyz2RgbBgrImpl!(isBgr, workingSpace)(conversionMatrix);});
    // No need to unpack output. Underlying data has already been changed.
    return output;
}

@fastmath
void xyz2RgbBgrImpl(bool isBgr, WorkingSpace workingSpace, T, U)(T pixelZip, Slice!(U, 2) conversionMatrix)
{
	import kaleidic.lubeck : mtimes;
	import mir.ndslice : each;
	
    // pixelZip[0] = input
    // pixelZip[1] = output

    // Convert to RGB
    // TODO: Is manual matrix math faster here?
    auto output = conversionMatrix.mtimes(sliced(pixelZip[0].ptr, 3));

    // Un-linearize
    output.each!((ref chnl)
    {
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

/**
Calculates the mean pixel value for an image.

Return semantics match mir.math.stat.mean.
*/
auto imageMean(Iterator)(Slice!(Iterator, 3) image)
in
{
    assert(image.shape[2] == 3, "Input requires 3 channels.");
}
do
{
    import mir.math.stat : mean;
    import mir.ndslice : byDim, map, slice;

    // TODO: Add option for segmenting image for calculating mean.
    // TODO: Add option to exclude top and bottom percentiles from mean.
    // dfmt off
    return image
        .byDim!2
        .map!(mean)
        .slice;
    //dfmt on
}

unittest
{
    // dfmt off
    ubyte[] rgb = [
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        120, 120, 120
    ];
    //dfmt on

    assert(rgb.sliced(4, 1, 3).imageMean == [93.75, 93.75, 93.75]);
}

Slice!(ReturnType*, dims) toUnsigned(ReturnType = ubyte, InputType, size_t dims)(Slice!(InputType*, dims) image)
in
{
    import std.traits : isFloatingPoint, isUnsigned;

    static assert(isFloatingPoint!InputType);
    static assert(isUnsigned!ReturnType);
}
do
{
    // TODO: Handle being passed an unsigned slice.
    import mir.ndslice : each, uninitSlice, zip;

    auto output = uninitSlice!ReturnType(image.shape);
    auto zipped = zip(image, output);
    zipped.each!((z) { toUnsignedImpl(z); });

    return output;
}

@fastmath
void toUnsignedImpl(T)(T zippedChnls)
{
    import std.math : round;
    
    alias UnsignedType = typeof(zippedChnls[1].__value());
    zippedChnls[1].__value() = cast(UnsignedType) round(zippedChnls[0].__value().clip!(0, 1) * UnsignedType.max);
}

unittest
{
    import std.math : approxEqual;
    import mir.ndslice : sliced;

    // dfmt off
    Slice!(double*, 3) rgb = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);

    ubyte[] rgbU = [
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        120, 120, 120
    ];
    Slice!(ubyte*, 3) rgbUnsigned = rgbU.sliced(4, 1, 3);
    //dfmt on

    assert(approxEqual(rgb.toUnsigned, rgbUnsigned));
}

Slice!(ReturnType*, 3) toFloating(ReturnType = double, InputType)(InputType[] image, uint width, uint height)
in
{
    import std.traits : isFloatingPoint, isUnsigned;

    static assert(isFloatingPoint!ReturnType);
    static assert(isUnsigned!InputType);
}
do
{
    import mir.ndslice : each, uninitSlice, zip;

    auto output = uninitSlice!ReturnType([height, width, 3]);
    auto zipped = zip(image.sliced(height, width, 3), output);
    zipped.each!((z) { toFloatingImpl(z); });

    return output;
}

@fastmath
private void toFloatingImpl(T)(T zippedChnls)
{
    alias UnsignedType = typeof(zippedChnls[0].__value());
    alias FloatingType = typeof(zippedChnls[1].__value());
    zippedChnls[1].__value() = cast(FloatingType) zippedChnls[0] / UnsignedType.max;
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

    Slice!(double*, 3) rgbDouble = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
        0.470588, 0.470588, 0.470588
    ].sliced(4, 1, 3);
    //dfmt on

    assert(approxEqual(rgb.toFloating(1, 4), rgbDouble));
}

/**
Standard illuminants.
*/
enum Illuminant
{
    d65 = [0.95047, 1.0, 1.08883]
}

enum ChromAdaptMethod
{
    bradford = "bradford"
}

private static immutable
{
    // dfmt off
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
    // dfmt on
}

auto pixelMap(alias fun, Iterator)(Slice!(Iterator, 3) image)
{
    import mir.ndslice : fuse, map, pack;

    return image
        .pack!1
        .map!(fun)
        .fuse;
}

/**
Inputs:
    RGB source image (double)
    XYZ white point of source image under source illuminant -> array to allow non-standard illuminants
    XYZ white point of destination illuminant -> array to support wide range of possible source illuminants
    working space

    is it pure if I pass in arrays?
*/
Slice!(Iterator, 3) chromAdapt(ChromAdaptMethod method = ChromAdaptMethod.bradford, Iterator)(Slice!(Iterator, 3) image, double[] srcIlluminant, double[] destIlluminant, WorkingSpace workingSpace = WorkingSpace.sRgb)
in
{
    import std.traits : isFloatingPoint;
    
    static assert(isFloatingPoint!(IteratorType!Iterator), "Image values must be floating point.");
    assert(srcIlluminant.length == 3);
    assert(destIlluminant.length == 3);
}
do
{
    import kaleidic.lubeck : mtimes;
    import mir.ndslice : diagonal, reshape, slice;

    auto xyz2Lms = mixin(method ~ "Xyz2Lms");
    auto lms2Xyz = mixin(method ~ "InvXyz2Lms");

    auto lmsSrc = xyz2Lms
        .sliced(3, 3)
        .mtimes(srcIlluminant.sliced(3, 1));
    

    auto lmsDest = xyz2Lms
        .sliced(3, 3)
        .mtimes(destIlluminant.sliced(3, 1));
    

    int err;
    auto lmsGain = slice!double([3, 3], 0); 
    auto diag = lmsGain.diagonal;
    diag[] = (lmsDest / lmsSrc).reshape([3], err);
    assert(err == 0);

    auto transform = lms2Xyz
        .sliced(3, 3)
        .mtimes(lmsGain)
        .mtimes(xyz2Lms.sliced(3, 3));

    return image
        .rgb2Xyz
        .pixelMap!(pixel => transform.mtimes(pixel))
        .xyz2Rgb;
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