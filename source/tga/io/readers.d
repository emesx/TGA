module tga.io.readers;

import std.exception, std.stdio;
import tga.model, tga.io.utils;

/**
 * Reads an image file.
 * If loadExtraFields is true, then it loads the footer and the developer fields.
 */
Image readImage(bool loadDeveloperField = false)(File file){
    Header header = readHeader(file);           
    validate(header);

    ubyte[] imageId  = readId(file, header);
    ubyte[] colorMap = readColorMap(file, header);
    ubyte[] pixels   = ImageReaderMap[header.imageType](file, header);
    static if(loadDeveloperField){
        Footer footer = readFooter(file);
        Image image = Image(header, imageId, colorMap, pixels, footer);
        if(footer.isValid){
            readDeveloperDirectory(file, image);
            readDeveloperArea(file, image);
        }
        return image;
    }else{
        return Image(header, imageId, colorMap, pixels);
    }
}

package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

Header readHeader(File file){
    // TODO read 18 bytes at once
    Header header = read!Header(file);
    /*header.idLength         = read!ubyte(file);
    header.colorMapType     = read!ColorMapType(file);
    header.imageType        = read!ImageType(file);
    header.colorMapOffset   = read!ushort(file);
    header.colorMapLength   = read!ushort(file);
    header.colorMapDepth    = read!ColorMapDepth(file);
    header.xOrigin          = read!ushort(file);
    header.yOrigin          = read!ushort(file);
    header.width            = read!ushort(file);
    header.height           = read!ushort(file);
    header.pixelDepth       = read!PixelDepth(file);
    header.imageDescriptor  = read!ubyte(file);*/
    return header;
}

Footer readFooter(File file){
    file.seek(Footer.sizeof * -1, SEEK_END);
    return read!Footer(file);
}

void readDeveloperDirectory(File file, ref Image image){
    if(image.footer.developerAreaOffset){
        file.seek(image.footer.developerAreaOffset);
        image.developerDirectory ~= read!DevAreaTag(file);
        ubyte[] buffer = new ubyte[]((image.developerDirectory[0].reserved - 1) * DevAreaTag.sizeof);
        image.developerDirectory ~= cast(DevAreaTag[])(cast(void[])file.rawRead(buffer));
    }
}

void readDeveloperArea(File file, ref Image image){
    foreach(entry; image.developerDirectory){
        ubyte[] buffer;
        file.seek(entry.offset);
        buffer.length = entry.fieldSize;
        file.rawRead(buffer);
        image.developerArea ~= DevArea(buffer);
    }
}

ubyte[] readId(File file, const ref Header header){
    if(header.idLength)
        return file.rawRead(new ubyte[header.idLength]);
    else
        return [];
}


ubyte[] readColorMap(File file, const ref Header header){
    if(header.colorMapType == ColorMapType.NOT_PRESENT)
        return [];

    /*auto unpack   = PixelUnpackerMap[header.colorMapDepth];
    auto colorMap = new Pixel[](header.colorMapLength);
    auto colorMapByteDepth = header.colorMapDepth / 8; 
    

    file.seek(header.colorMapOffset * colorMapByteDepth , SEEK_CUR);

    ubyte[PixelDepth.max/8] buffer;
    foreach(uint i; 0 .. (header.colorMapLength - header.colorMapOffset)){
        file.rawRead(buffer[0 .. colorMapByteDepth]);
        colorMap[i] = unpack(buffer[0 .. colorMapByteDepth]);
    }*/
    
    //return colorMap;
    return file.rawRead(new ubyte[(header.colorMapDepth / 8) * header.colorMapLength]);
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


ubyte[] readUncompressed(File file, const ref Header header){
    auto pixels = new ubyte[](header.height * header.width * (header.pixelDepth / 8));
    //auto unpack = PixelUnpackerMap[header.pixelDepth];

    /*auto handle = (isColorMapped(header))
                    ? (ubyte[] b) => colorMap[sliceToNative!uint(b)]  
                    : (ubyte[] b) => unpack(b);*/

    /*auto pixelByteDepth = header.pixelDepth / 8;

    ubyte[PixelDepth.max/8] buffer;
    foreach(ref pixel; pixels) {
        file.rawRead(buffer[0 .. pixelByteDepth]);
        pixel = handle(buffer[0 .. pixelByteDepth]);
    }*/

    //return pixels;
     return file.rawRead(pixels);
}


ubyte[] readCompressed(File file, const ref Header header){
    auto pixels = new ubyte[](header.height * header.width);
    //auto unpack = PixelUnpackerMap[header.pixelDepth];

    /*auto handle = (isColorMapped(header))
                    ? (ubyte[] b) => colorMap[sliceToNative!uint(b)]
                    : (ubyte[] b) => unpack(b);*/

    auto pixelByteDepth = header.pixelDepth / 8;

    uint i = 0;
    ubyte[5] buffer;
    ubyte[] buffer0;
    while(i < header.height * header.width * pixelByteDepth) {
        file.rawRead(buffer[0 .. pixelByteDepth+1]);
        uint repetions = buffer[0] & 0x7F;
        
        for(int j; j < buffer.length; j++){
            pixels[i] = buffer[j+1];
            i++;
        }

        
        if(buffer[0] & 0x80){   /* RLE */
            for (uint j=0; j < repetions * pixelByteDepth; j++, i++) {
                pixels[i] = buffer[(j & (pixelByteDepth-1)) + 1];
            }
        }else {/* Normal */
            /*for (uint j=0; j<repetions; j++, i++) {
                file.rawRead(buffer[0 .. pixelByteDepth]);
                pixels[i] = handle(buffer);
            }*/
            buffer0.length = repetions * pixelByteDepth;
            file.rawRead(buffer0);
            for (uint j=0; j < repetions * pixelByteDepth; j++, i++) {
                pixels[i] = buffer[j];
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
