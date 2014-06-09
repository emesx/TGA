module tga.io.writers;

import std.stdio;
import tga.model, tga.io.utils;


void writeImage(File file, ref Image image){
    validate(image);

    writeHeader(file, image);
    writeId(file, image);
    writeColorMap(file, image);

    ImageWriterMap[image.header.imageType](file, image);
}


package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

void writeHeader(File file, in Image image){
    auto header = &image.header;

    write(file, cast(ubyte)(image.id.length));
    write(file, isColorMapped(image.header) ? ColorMapType.PRESENT : ColorMapType.NOT_PRESENT);
    write(file, header.imageType);
    write(file, header.colorMapOffset);      //TODO this should be taken from just-built color map, not from header
    write(file, header.colorMapLength);
    write(file, header.colorMapDepth);
    write(file, header.xOrigin);
    write(file, header.yOrigin);
    write(file, header.width);
    write(file, header.height);
    write(file, header.pixelDepth);
    write(file, header.imageDescriptor);
}


void writeId(File file, in Image image){
    if(image.id.length > 0)
        file.rawWrite(image.id);
}


void writeColorMap(File file, in Image image){
    if(!isColorMapped(image.header))
        return;

    auto pack = PixelPackerMap[image.header.colorMapDepth];

    foreach(Pixel p; image.colorMap) //TODO ref / const ref
        file.rawWrite(pack(p));
}


/* --- Image data writers ------------------------------------------------------------------------------------------- */

enum ImageWriterMap = [
    ImageType.UNCOMPRESSED_MAPPED     : &writeUncompressed,
    ImageType.UNCOMPRESSED_GRAYSCALE  : &writeUncompressed,
    ImageType.UNCOMPRESSED_TRUE_COLOR : &writeUncompressed,

    ImageType.COMPRESSED_MAPPED       : &writeCompressed,
    ImageType.COMPRESSED_GRAYSCALE    : &writeCompressed,
    ImageType.COMPRESSED_TRUE_COLOR   : &writeCompressed
];


void writeUncompressed(ref File file, ref Image image){
    auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                    ? (ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), image.header.pixelDepth/8)
                    : (ref Pixel p) => pack(p);

    foreach(ref Pixel p; image.pixels)
        file.rawWrite(handle(p));
}


void writeCompressed(ref File file, ref Image image){
    auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                    ? (ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), image.header.pixelDepth/8)
                    : (ref Pixel p) => pack(p);

    Pixel last   = image.pixels[0];
    ubyte length = 1;
    bool  duringRLE  = true;
    uint  chunkStart = 0;

    void writeNormal(Pixel[] pixels){
        if(pixels.length <= 0)
            return;

        write(file, cast(ubyte)((pixels.length-1) & 0x7F));

        foreach(ref Pixel p; pixels)
            file.rawWrite(handle(p));
    }

    void writeRLE(ref Pixel pixel, ubyte times){
        if(times <= 0)
            return;

        write(file, cast(ubyte)((times-1) | 0x80));
        file.rawWrite(handle(pixel));
    }

    foreach(uint offset, ref Pixel current; image.pixels[1 .. $]){
        offset += 1;

        if(current == last){
            if(duringRLE){
                length++;
                if(length == 128){
                    writeRLE(last, 128);
                    length = 0;
                }
            }
            else {
                writeNormal(image.pixels[chunkStart .. chunkStart+length-1]);
                duringRLE = true;
                length = 2;
            }

        } 

        else {
            if(duringRLE){
                writeRLE(last, length);

                duringRLE = false;
                length = 1;
                chunkStart = offset;
            }
            else {
                length++;
                if(length == 128){
                    writeNormal(image.pixels[chunkStart .. chunkStart+128]);
                    length = 1;
                    chunkStart = offset;
                }
            }
        }

        last = current;
    } // for

    if(duringRLE)
        writeRLE(last, length);
    else
        writeNormal(image.pixels[chunkStart .. chunkStart+length]);

}



/* --- Pixel packers ------------------------------------------------------------------------------------------------ */

enum PixelPackerMap = [
    32 : &pack32,
    24 : &pack24,
    16 : &pack16,
     8 : &pack8
];


ubyte[] pack32(ref Pixel pixel){
    return pixel.bytes;
}

ubyte[] pack24(ref Pixel pixel){
    return pixel.bytes[0 .. 3];
}

ubyte[] pack16(ref Pixel pixel){
    ubyte[] chunk = new ubyte[](2);

    chunk[0] = ((pixel.g & 0x38) << 2) | (pixel.b >> 3);
    chunk[1] = (pixel.a & 0x80) | ((pixel.r & 0xF8) >> 1) | (pixel.g & 0xC0 >> 6);

    return chunk;
}

ubyte[] pack8(ref Pixel pixel){
    uint grey = (pixel.r + pixel.g + pixel.b)/3;
    return [cast(ubyte)(grey)];
}
