module tga.io.readers;

import std.exception, std.stdio;
import tga.model, tga.io.utils;


Image readImage(File file){
    Header header = readHeader(file);           
    validate(header);

    ubyte[] imageId  = readId(file, header);
    Pixel[] colorMap = readColorMap(file, header);
    Pixel[] pixels   = ImageReaderMap[header.imageType](file, header, colorMap);

    return Image(header, imageId, pixels);
}


package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

Header readHeader(File file){
    // TODO read 18 bytes at once
    Header header;
    header.idLength         = read!ubyte(file);
    header.colorMapType     = read!ColorMapType(file);
    header.imageType        = read!ImageType(file);
    header.colorMapOffset   = read!ushort(file);
    header.colorMapLength   = read!ushort(file);
    header.colorMapDepth    = read!ubyte(file);
    header.xOrigin          = read!ushort(file);
    header.yOrigin          = read!ushort(file);
    header.width            = read!ushort(file);
    header.height           = read!ushort(file);
    header.pixelDepth       = read!ubyte(file);
    header.imageDescriptor  = read!ubyte(file);
    return header;
}


ubyte[] readId(File file, in Header header){
    if(header.idLength)
        return rawRead(file, header.idLength);
    else
        return [];
}


Pixel[] readColorMap(File file, in Header header){
    if(header.colorMapType == ColorMapType.NOT_PRESENT)
        return [];

    auto pixelReader       = PixelUnpackerMap[header.colorMapDepth];
    auto colorMapByteDepth = header.colorMapDepth / 8; 
    auto colorMap          = new Pixel[](header.colorMapLength);

    file.seek(header.colorMapOffset * colorMapByteDepth , SEEK_CUR);

    foreach(uint i; 0 .. (header.colorMapLength - header.colorMapOffset)){
        ubyte[] bytes = rawRead(file, colorMapByteDepth);
        colorMap[i]   = pixelReader(bytes);
    }

    return colorMap;
}


/* --- Image data readers ------------------------------------------------------------------------------------------- */

enum ImageReaderMap = [
    ImageType.UNCOMPRESSED_MAPPED     : &readUncompressed,
    ImageType.UNCOMPRESSED_GRAYSCALE  : &readUncompressed,
    ImageType.UNCOMPRESSED_TRUE_COLOR : &readUncompressed,

    ImageType.COMPRESSED_MAPPED       : &readCompressed,
    ImageType.COMPRESSED_GRAYSCALE    : &readCompressed,
    ImageType.COMPRESSED_TRUE_COLOR   : &readCompressed
];


Pixel[] readUncompressed(File file, in Header header, Pixel[] colorMap){
    auto pixels = new Pixel[](header.height * header.width);
    auto unpack = PixelUnpackerMap[header.pixelDepth];

    auto handle = (header.colorMapType == ColorMapType.NOT_PRESENT)
                    ? (ubyte[] b) => unpack(b) 
                    : (ubyte[] b) => colorMap[sliceToNative!uint(b)] ;
    
    foreach(uint i; 0 .. header.height * header.width) {
        ubyte[] bytes = rawRead(file, header.pixelDepth / 8);
        pixels[i]     = handle(bytes);
    }

    return pixels;
}


Pixel[] readCompressed(File file, in Header header,  Pixel[] colorMap){
    auto pixels = new Pixel[](header.height * header.width);
    auto unpack = PixelUnpackerMap[header.pixelDepth];

    auto handle = (header.colorMapType == ColorMapType.NOT_PRESENT)
                    ? (ubyte[] b) => unpack(b) 
                    : (ubyte[] b) => colorMap[sliceToNative!uint(b)] ;

    uint i = 0;
    while(i < header.height * header.width) {
        ubyte[] bytes = rawRead(file, 1 + header.pixelDepth / 8);
        uint repetions = bytes[0] & 0x7F;
        
        pixels[i] = handle(bytes[1 .. $]);
        i++;

        /* RLE */
        if(bytes[0] & 0x80){   
            for (uint j=0; j<repetions; j++, i++) {
                pixels[i] = handle(bytes[1 .. $]);
            }
        }

        /* Normal */
        else {
            for (uint j=0; j<repetions; j++, i++) {
                bytes = rawRead(file, header.pixelDepth / 8);
                pixels[i] = handle(bytes);
            }
        }          
    }

    return pixels; 
}


/* --- Pixel unpackers ---------------------------------------------------------------------------------------------- */

enum PixelUnpackerMap = [
    32 : &unpack32,
    24 : &unpack24,
    16 : &unpack16,
     8 : &unpack8
];

Pixel unpack32(in ubyte[] chunk){
    Pixel pixel;
    pixel.r = chunk[2];
    pixel.g = chunk[1];
    pixel.b = chunk[0];
    pixel.a = chunk[3];
    return pixel;
}

Pixel unpack24(in ubyte[] chunk){
    Pixel pixel;
    pixel.r = chunk[2];
    pixel.g = chunk[1];
    pixel.b = chunk[0];
    pixel.a = 0xFF;
    return pixel;
}

Pixel unpack16(in ubyte[] chunk){
    Pixel pixel;
    pixel.r = (chunk[1] & 0x7C) << 1;
    pixel.g = ((chunk[1] & 0x03) << 6) | ((chunk[0] & 0xE0) >> 2);
    pixel.b = (chunk[0] & 0x1F) << 3;
    pixel.a = (chunk[1] & 0x80) ? 0xFF : 0;
    return pixel;
}

Pixel unpack8(in ubyte[] chunk){
    Pixel pixel;
    pixel.r = pixel.g = pixel.b = chunk[0];
    pixel.a = 255;
    return pixel;
}
