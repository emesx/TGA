module tga.io.readers;

import std.exception, std.stdio;
import tga.model, tga.io.utils;


Image readImage(File file){
    Header header = readHeader(file);           
    validate(header);

    ubyte[] imageId  = readId(file, header);
    Pixel[] colorMap = readColorMap(file, header);
    Pixel[] pixels   = ImageReaderMap[header.imageType](file, header, colorMap);

    return Image(header, imageId, colorMap, pixels);
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
        return file.rawRead(new ubyte[header.idLength]);
    else
        return [];
}


Pixel[] readColorMap(File file, in Header header){
    if(header.colorMapType == ColorMapType.NOT_PRESENT)
        return [];

    auto unpack   = PixelUnpackerMap[header.colorMapDepth];
    auto colorMap = new Pixel[](header.colorMapLength);
    auto colorMapByteDepth = header.colorMapDepth / 8; 
    

    file.seek(header.colorMapOffset * colorMapByteDepth , SEEK_CUR);

    ubyte[MAX_BYTE_DEPTH] buffer;
    foreach(uint i; 0 .. (header.colorMapLength - header.colorMapOffset)){
        file.rawRead(buffer[0 .. colorMapByteDepth]);
        colorMap[i] = unpack(buffer[0 .. colorMapByteDepth]);
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


Pixel[] readUncompressed(File file, in Header header, in Pixel[] colorMap){
    auto pixels = new Pixel[](header.height * header.width);
    auto unpack = PixelUnpackerMap[header.pixelDepth];

    auto handle = (isColorMapped(header))
                    ? (ubyte[] b) => colorMap[sliceToNative!uint(b)]  
                    : (ubyte[] b) => unpack(b);

    auto pixelByteDepth = header.pixelDepth / 8;

    ubyte[MAX_BYTE_DEPTH] buffer;
    foreach(uint i; 0 .. header.height * header.width) {
        file.rawRead(buffer[0 .. pixelByteDepth]);
        pixels[i]  = handle(buffer[0 .. pixelByteDepth]);
    }

    return pixels;
}


Pixel[] readCompressed(File file, in Header header,  in Pixel[] colorMap){
    auto pixels = new Pixel[](header.height * header.width);
    auto unpack = PixelUnpackerMap[header.pixelDepth];

    auto handle = (isColorMapped(header))
                    ? (ubyte[] b) => colorMap[sliceToNative!uint(b)]
                    : (ubyte[] b) => unpack(b);

    auto pixelByteDepth = header.pixelDepth / 8;

    uint i = 0;
    ubyte[MAX_BYTE_DEPTH+1] buffer;
    while(i < header.height * header.width) {
        file.rawRead(buffer[0 .. pixelByteDepth+1]);
        uint repetions = buffer[0] & 0x7F;
        
        pixels[i] = handle(buffer[1 .. pixelByteDepth+1]);
        i++;

        /* RLE */
        if(buffer[0] & 0x80){   
            for (uint j=0; j<repetions; j++, i++) {
                pixels[i] = handle(buffer[1 .. pixelByteDepth+1]);
            }
        }

        /* Normal */
        else {
            for (uint j=0; j<repetions; j++, i++) {
                file.rawRead(buffer[0 .. pixelByteDepth]);
                pixels[i] = handle(buffer);
            }
        }          
    } // while

    return pixels; 
}


/* --- Pixel unpackers ---------------------------------------------------------------------------------------------- */

enum PixelUnpackerMap = [
    32 : &unpack32,
    24 : &unpack24,
    16 : &unpack16,
     8 : &unpack8
];

immutable MAX_BYTE_DEPTH = 4;

Pixel unpack32(in ubyte[] chunk){
    Pixel pixel;
    pixel.bytes[] = chunk[];
    return pixel;
}

Pixel unpack24(in ubyte[] chunk){
    Pixel pixel;
    pixel.bytes[0..3] = chunk[];
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
    pixel.a = 0xFF;
    return pixel;
}
