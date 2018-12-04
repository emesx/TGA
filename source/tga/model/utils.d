module tga.model.utils;

import std.algorithm, std.conv, std.exception;
import tga.model.types, tga.model.validation;


pure nothrow bool hasAlpha(const ref Header header){
    return !!(isColorMapped(header)
                ? header.colorMapDepth.among(ColorMapDepth.BPP16, ColorMapDepth.BPP32)
                : header.pixelDepth.among(PixelDepth.BPP16, PixelDepth.BPP32));
}

pure nothrow bool isTrueColor(const ref Header header){
    return !!header.imageType.among(ImageType.UNCOMPRESSED_TRUE_COLOR, ImageType.COMPRESSED_TRUE_COLOR);
}

pure nothrow bool isColorMapped(const ref Header header){
    return !!header.imageType.among(ImageType.UNCOMPRESSED_MAPPED, ImageType.COMPRESSED_MAPPED);
}

pure nothrow bool isGrayScale(const ref Header header){
    return !!header.imageType.among(ImageType.UNCOMPRESSED_GRAYSCALE, ImageType.COMPRESSED_GRAYSCALE);
}


/* --- Image Origin and Pixel Order --------------------------------------------------------------------------------- */

pure nothrow bool isUpsideDown(const ref Header header){
    return getImageOrigin(header) == ImageOrigin.BOTTOM_LEFT;
}

pure nothrow ImageOrigin getImageOrigin(const ref Header header){
    return (header.imageDescriptor & 0b0010_0000) 
                ? ImageOrigin.TOP_LEFT
                : ImageOrigin.BOTTOM_LEFT;
}

nothrow void setImageOrigin(ref Header header, ImageOrigin origin){
    header.imageDescriptor &= 0b1101_1111;

    if(origin == ImageOrigin.TOP_LEFT)
        header.imageDescriptor |= 0b0010_0000;
}



pure nothrow bool isRightToLeft(const ref Header header){
    return getPixelOrder(header) == PixelOrder.RIGHT_TO_LEFT;
}

pure nothrow PixelOrder getPixelOrder(const ref Header header){
    return (header.imageDescriptor & 0b0001_0000) 
                ? PixelOrder.RIGHT_TO_LEFT
                : PixelOrder.LEFT_TO_RIGHT;
}

nothrow void setPixelOrder(ref Header header, PixelOrder order){
    header.imageDescriptor &= 0b1110_1111;

    if(order == PixelOrder.RIGHT_TO_LEFT)
        header.imageDescriptor |= 0b0001_0000;
}


/** 
 * Transform pixels in-place to a standard row-major, top-to-bottom, left-to-right order.
 * The tranformation to perform depends on the information from the header.
 */
void normalizeOrigin(ref Image image){
    immutable uint h = image.header.height, w = (image.header.width * image.header.pixelDepth) / 8;

    if(image.header.isUpsideDown())
        foreach(uint y; 0 .. h/2) {
            ubyte[] row1 = image.pixels[y*w .. (y+1)*w];
            ubyte[] row2 = image.pixels[(h-1-y)*w .. (h-y)*w];
            swapRanges(row1,row2);
        }

    if(image.header.isRightToLeft())
        foreach(uint y; 0 .. h) {
            switch(image.header.pixelDepth){
                case PixelDepth.BPP8:
                    ubyte[] row = image.pixels[y*w .. (y+1)*w];
                    reverse(row);
                    break;
                case PixelDepth.BPP16:
                    ushort[] row = cast(ushort[])(cast(void[])image.pixels[y*w .. (y+1)*w]);
                    reverse(row);
                    break;
                case PixelDepth.BPP32:
                    uint[] row = cast(uint[])(cast(void[])image.pixels[y*w .. (y+1)*w]);
                    reverse(row);
                    break;
                default:
                    break;
            }
        }
}

/* --- Color Map ---------------------------------------------------------------------------------------------------- */

ushort indexInColorMap(in Pixel[] colorMap, const ref Pixel pixel){
    // TODO O(n) that should be O(1)
    const index = colorMap.countUntil(pixel);
    enforce(index >= 0, "Pixel color not found in color map: " ~ pixel.text);
    return to!ushort(index);
}

/**
 * Construct a color map and assign it to the passed in Image. Update all necessary header fields.
 */
Pixel[] buildColorMap(in Pixel[] pixels){
    // TODO O(n^2) that should be O(n)
    Pixel[] colorMap = [];

    foreach(p; pixels)
        if(!colorMap.canFind(p))
            colorMap ~= p;

    return colorMap;
}


/* --- Image factories ---------------------------------------------------------------------------------------------- */

/**
 * Create an uncompressed true-color image with 32-bit color depth.
 *
 * This is the simplest factory function and should be used by default.
 *
 * It expects the pixels to be in the classic row-major, left-to-right form, since the created header will have
 * the origin set to top-left corner with pixels running from left to right. The created image will contain
 * no color map and no id contents.
 */
Image createImage(Pixel[] pixels, ushort width, ushort height){
    return createImage(cast(ubyte[])(cast(void[])pixels), width, height, ImageType.UNCOMPRESSED_TRUE_COLOR, PixelDepth.BPP32);
}

/**
 * Create an image of specified type.
 *
 * This overload makes it possible to specify the ImageType and pixel bit depth.
 * It expects the pixels to be in the form specified by imageOrigin and pixelOrder (this function doesn't transform
 * the pixels, the parameters are for header only).
 * 
 * If the imageType is color-mapped then a color map will be constructed from the pixels and assigned to the image;
 * the header will be updated according to the color map. The input pixels remain unaffected in any case.
 * The created image will contain no id contents.
 *
 * NOTE: Creating color map currently only works with 32bit images and color maps.
 */
Image createImage(ubyte[] pixels, ushort width, ushort height, ImageType imageType, PixelDepth pixelDepth,
                  ImageOrigin imageOrigin = ImageOrigin.TOP_LEFT,
                  PixelOrder pixelOrder   = PixelOrder.LEFT_TO_RIGHT){

    Header header;

    header.imageType  = imageType;
    header.pixelDepth = isGrayScale(header) ? PixelDepth.BPP8 : pixelDepth;
    header.width      = width;
    header.height     = height;

    setImageOrigin(header, imageOrigin);
    setPixelOrder(header, pixelOrder);

    Image image = Image(header, [], [], pixels);

    if(isColorMapped(header))
        createColorMapAndUpdate(image);

    validate(image);  
    return image;   
}
Image createImage(Pixel[] pixels, ushort width, ushort height, ImageType imageType, PixelDepth pixelDepth,
                  ImageOrigin imageOrigin = ImageOrigin.TOP_LEFT,
                  PixelOrder pixelOrder   = PixelOrder.LEFT_TO_RIGHT){
    return createImage(cast(ubyte[])(cast(void[])pixels), width, height, imageType, pixelDepth, imageOrigin, pixelOrder);
}

package void createColorMapAndUpdate(ref Image image){

    auto colorMap = buildColorMap(cast(Pixel[])(cast(void[])image.pixels));
    auto header = &image.header;

    image.colorMap = cast(ubyte[])(cast(void[])colorMap);
    header.colorMapType = ColorMapType.PRESENT;
    header.colorMapOffset = 0;
    header.colorMapLength = to!ushort(colorMap.length);
    header.colorMapDepth  = to!ColorMapDepth(to!ubyte(header.pixelDepth));
    header.pixelDepth = colorMap.length < 256 ? PixelDepth.BPP8 : PixelDepth.BPP16;
}