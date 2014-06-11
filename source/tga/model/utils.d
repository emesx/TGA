module tga.model.utils;

import std.algorithm, std.conv;
import tga.model.types, tga.model.validation;


pure bool hasAlpha(in Header header){
    return isColorMapped(header)
                ? [16, 32].canFind(header.colorMapDepth)
                : [16, 32].canFind(header.pixelDepth);
}

pure bool isTrueColor(in Header header){
    return [ImageType.UNCOMPRESSED_TRUE_COLOR, ImageType.COMPRESSED_TRUE_COLOR].canFind(header.imageType);
}

pure bool isColorMapped(in Header header){
    return [ImageType.UNCOMPRESSED_MAPPED, ImageType.COMPRESSED_MAPPED].canFind(header.imageType);
}

pure bool isGrayScale(in Header header){
    return [ImageType.UNCOMPRESSED_GRAYSCALE, ImageType.COMPRESSED_GRAYSCALE].canFind(header.imageType);
}


/* --- Image Origin and Pixel Order --------------------------------------------------------------------------------- */

pure bool isUpsideDown(in Header header){
    return getImageOrigin(header) == ImageOrigin.BOTTOM_LEFT;
}

pure ImageOrigin getImageOrigin(in Header header){
    return (header.imageDescriptor & 0b0010_0000) 
                ? ImageOrigin.TOP_LEFT
                : ImageOrigin.BOTTOM_LEFT;
}

void setImageOrigin(ref Header header, ImageOrigin origin){
    header.imageDescriptor &= 0b1101_1111;

    if(origin == ImageOrigin.TOP_LEFT)
        header.imageDescriptor |= 0b0010_0000;
}



pure bool isRightToLeft(in Header header){
    return getPixelOrder(header) == PixelOrder.RIGHT_TO_LEFT;
}

pure PixelOrder getPixelOrder(in Header header){
    return (header.imageDescriptor & 0b0001_0000) 
                ? PixelOrder.RIGHT_TO_LEFT
                : PixelOrder.LEFT_TO_RIGHT;
}

void setPixelOrder(ref Header header, PixelOrder order){
    header.imageDescriptor &= 0b1110_1111;

    if(order == PixelOrder.RIGHT_TO_LEFT)
        header.imageDescriptor |= 0b0001_0000;
}


/** 
 * Transform pixels in-place to a standard row-major, top-to-bottom, left-to-right order.
 * The tranformation to perform depends on the information from the header.
 */
void normalizeOrigin(ref Image image){
    immutable h = image.header.height,
              w = image.header.width;

    if(image.header.isUpsideDown())
        foreach(uint y; 0 .. h/2) {
            Pixel[] row1 = image.pixels[y*w .. (y+1)*w];
            Pixel[] row2 = image.pixels[(h-1-y)*w .. (h-y)*w];
            std.algorithm.swapRanges(row1,row2);
        }

    if(image.header.isRightToLeft())
        foreach(uint y; 0 .. h) {
            Pixel[] row = image.pixels[y*w .. (y+1)*w];
            std.algorithm.reverse(row);
        }
}

/* --- Color Map ---------------------------------------------------------------------------------------------------- */

ushort indexInColorMap(in Pixel[] colorMap, in Pixel pixel){
    // TODO O(n) that should be O(1)
    foreach(uint idx; 0 .. colorMap.length)
        if(colorMap[idx] == pixel)
            return cast(ushort)idx;

    throw new Exception("Pixel color not found in color map: " ~ to!string(pixel));
}

/**
 * Construct a color map and assign it to the passed in Image. Update all necessary header fields.
 */
Pixel[] buildColorMap(in Pixel[] pixels){
    Pixel[] colorMap = [];

    foreach(p; pixels)
        if(!std.algorithm.canFind(colorMap, p))
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
    return createImage(pixels, width, height, ImageType.UNCOMPRESSED_TRUE_COLOR, 32);
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
 */
Image createImage(Pixel[] pixels, ushort width, ushort height, ImageType imageType, ubyte pixelDepth,
                  ImageOrigin imageOrigin = ImageOrigin.TOP_LEFT,
                  PixelOrder pixelOrder   = PixelOrder.LEFT_TO_RIGHT){

    Header header;

    header.imageType  = imageType;
    header.pixelDepth = isGrayScale(header) ? 8 : pixelDepth;
    header.width      = width;
    header.height     = height;

    setImageOrigin(header, imageOrigin);
    setPixelOrder(header, pixelOrder);

    Image image = {header: header, pixels: pixels};

    if(isColorMapped(header))
        createColorMapAndUpdate(image);

    validate(image);  
    return image;   
}

package void createColorMapAndUpdate(ref Image image){

    auto colorMap = buildColorMap(image.pixels);
    auto header = &image.header;

    image.colorMap = colorMap;
    header.colorMapType = ColorMapType.PRESENT;
    header.colorMapOffset = 0;
    header.colorMapLength = cast(ushort)(colorMap.length);
    header.colorMapDepth = header.pixelDepth;
    header.pixelDepth = colorMap.length < 256 ? 8 : 16;
}