module photog.utils;

import mir.ndslice : Slice, sliced, SliceKind;

/**
Convert [M, N, P] slice to [MxN] slice of [P] arrays.
*/
auto pixelPack(size_t chnls, InputType, size_t dims, SliceKind kind)(
        Slice!(InputType*, dims, kind) image)
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

///
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
auto pixelUnpack(size_t chnls, InputType, size_t dims, SliceKind kind)(
        Slice!(InputType*, dims, kind) image, size_t height, size_t width)
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

///
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

/**
Clip value to the range provided.
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
template IteratorType(Iterator)
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
size_t[] dimensions(T)(T arr, size_t[] dims = [])
{
    import std.traits : isNumeric;

    static if (isNumeric!T)
        return dims;
    else
    {
        dims ~= arr.length;
        return dimensions(arr[0], dims);
    }
}

///
unittest
{
    import mir.ndslice : slice;

    size_t[3] expectedDims = [1, 2, 3];
    auto a = slice!double(expectedDims, 0);
    assert(a.dimensions == expectedDims);
}

/**
Convert floating point input to unsigned.
*/
Slice!(ReturnType*, dims) toUnsigned(ReturnType = ubyte, InputType, size_t dims)(
        Slice!(InputType*, dims) input)
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

    auto output = uninitSlice!ReturnType(input.shape);
    auto zipped = zip(input, output);
    zipped.each!((z) { toUnsignedImpl(z); });

    return output;
}

///
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

private void toUnsignedImpl(T)(T zippedChnls)
{
    import std.math : round;

    alias UnsignedType = typeof(zippedChnls[1].__value());
    zippedChnls[1].__value() = cast(UnsignedType) round(zippedChnls[0].__value()
            .clip!(0, 1) * UnsignedType.max);
}

/**
Convert unsigned input to floating point.
*/
Slice!(ReturnType*, 3) toFloating(ReturnType = double, InputType)(InputType[] input,
        uint width, uint height)
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
    auto zipped = zip(input.sliced(height, width, 3), output);
    zipped.each!((z) { toFloatingImpl(z); });

    return output;
}

///
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

private void toFloatingImpl(T)(T zippedChnls)
{
    alias UnsignedType = typeof(zippedChnls[0].__value());
    alias FloatingType = typeof(zippedChnls[1].__value());
    zippedChnls[1].__value() = cast(FloatingType) zippedChnls[0] / UnsignedType.max;
}

/**
Calculate the mean pixel value for an image.

Return semantics match mir.math.stat.mean.
*/
auto imageMean(T)(Slice!(T, 3) image)
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

///
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

/**
Map a function across an image's pixels.
*/
auto pixelMap(alias fun, Iterator)(Slice!(Iterator, 3) image)
{
    import mir.ndslice : fuse, map, pack;

    return image.pack!1
        .map!(fun)
        .fuse;
}
