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

ushort indexInColorMap(in Pixel[] colorMap, ref Pixel pixel){
    // TODO O(n) that should be O(1)
    foreach(uint idx; 0 .. colorMap.length)
        if(colorMap[idx] == pixel)
            return cast(ushort)idx;

    throw new Exception("Pixel color not found in color map: " ~ to!string(pixel));
}

/**
 * Construct a color map and assign it to the passed in Image. Update all necessary header fields.
 */
Pixel[] buildColorMap(Pixel[] pixels){
    auto colorMap = new Pixel[](1);

    foreach(ref Pixel p; pixels)
        if(!std.algorithm.canFind(colorMap, p))
            colorMap ~= p;

    return colorMap;
}


/* --- Safe house --------------------------------------------------------------------------------------------------- */

Image createImage(Pixel[] pixels, ushort width, ushort height){
    Header header;

    header.imageType = ImageType.UNCOMPRESSED_TRUE_COLOR;
    header.setImageOrigin(ImageOrigin.TOP_LEFT);
    header.setPixelOrder(PixelOrder.LEFT_TO_RIGHT);
    header.pixelDepth = 32;
    header.width  = width;
    header.height = height;
    

    Image image = {header: header, pixels: pixels};
    validate(image);

    return image;   
}

Image createImage(Pixel[] pixels, ushort width, ushort height, ImageType imageType,
                  ImageOrigin imageOrigin = ImageOrigin.TOP_LEFT, PixelOrder pixelOrder = PixelOrder.LEFT_TO_RIGHT){

    Header header;

    header.imageType = imageType;
    header.setImageOrigin(imageOrigin);
    header.setPixelOrder(pixelOrder);
    header.pixelDepth = 32;
    header.width  = width;
    header.height = height;

    Pixel[] colorMap = [];    

    if(isColorMapped(header)){
        colorMap = buildColorMap(pixels);
        header.colorMapType   = ColorMapType.PRESENT;
        header.colorMapLength = cast(ushort)(colorMap.length);
        header.colorMapDepth  = 32;
        header.pixelDepth     = colorMap.length < 256 ? 8 : 16;
    }


    Image image = {header: header, colorMap: colorMap, pixels: pixels};
    validate(image);
    
    return image;   
}

void synchronizeImage(ref Image image){
    validate(image);
    image.header.idLength = cast(ubyte)(image.id.length);
    normalizeOrigin(image);
}
