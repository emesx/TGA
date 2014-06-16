module tga.io.writers;

import std.stdio;
import tga.model, tga.io.utils;


void writeImage(File file, const ref Image image){
    validate(image);

    writeHeader(file, image);
    writeId(file, image);
    writeColorMap(file, image);

    ImageWriterMap[image.header.imageType](file, image);
}


package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

void writeHeader(File file, const ref Image image){
    auto header = &image.header;

    write(file, header.idLength);
    write(file, header.colorMapType);
    write(file, header.imageType);
    write(file, header.colorMapOffset);
    write(file, header.colorMapLength);
    write(file, header.colorMapDepth);
    write(file, header.xOrigin);
    write(file, header.yOrigin);
    write(file, header.width);
    write(file, header.height);
    write(file, header.pixelDepth);
    write(file, header.imageDescriptor);
}


void writeId(File file, const ref Image image){
    if(image.id.length > 0)
        file.rawWrite(image.id);
}


void writeColorMap(File file, const ref Image image){
    if(!isColorMapped(image.header))
        return;

    ubyte[MAX_BYTE_DEPTH] buffer;

    auto pixelByteDepth = image.header.colorMapDepth/8;
    auto pack  = PixelPackerMap[image.header.colorMapDepth];

    foreach(_ ; 0 .. image.header.colorMapOffset){
        file.rawWrite(buffer[0 ..pixelByteDepth]);
    }

    foreach(Pixel p; image.colorMap){
        pack(p, buffer);
        file.rawWrite(buffer[0 .. pixelByteDepth]);
    }
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


void writeUncompressed(ref File file, const ref Image image){
    ubyte[MAX_BYTE_DEPTH] buffer;

    auto pixelByteDepth = image.header.pixelDepth/8;
    auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                    ? (const ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), pixelByteDepth, buffer)
                    : (const ref Pixel p) => pack(p, buffer);

    foreach(p; image.pixels){
        handle(p);
        file.rawWrite(buffer[0 .. pixelByteDepth]);
    }
}


void writeCompressed(ref File file, const ref Image image){
    ubyte[MAX_BYTE_DEPTH] buffer;

    Pixel last      = image.pixels[0];
    ubyte length    = 1;
    bool duringRLE  = true;
    uint chunkStart = 0;

    auto pixelByteDepth = image.header.pixelDepth/8;
    auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                    ? (const ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), pixelByteDepth, buffer)
                    : (const ref Pixel p) => pack(p, buffer);


    void writeNormal(in Pixel[] pixels){
        if(pixels.length <= 0)
            return;

        write(file, cast(ubyte)((pixels.length-1) & 0x7F));

        foreach(p; pixels){
            handle(p);
            file.rawWrite(buffer[0 .. pixelByteDepth]);
        }
    }


    void writeRLE(in Pixel pixel, ubyte times){
        if(times <= 0)
            return;

        write(file, cast(ubyte)((times-1) | 0x80));
        handle(pixel);
        file.rawWrite(buffer[0 .. pixelByteDepth]);
    }


    foreach(offset, current; image.pixels[1 .. $]){
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


void pack32(const ref Pixel pixel, ubyte[] buffer){
    buffer[0 .. 4] = pixel.bytes;
}

void pack24(const ref Pixel pixel, ubyte[] buffer){
    buffer[0 .. 3] = pixel.bytes[0 .. 3];
}

void pack16(const ref Pixel pixel, ubyte[] buffer){
    buffer[0] = cast(ubyte)((pixel.g << 2) | (pixel.b >> 3));
    buffer[1] = cast(ubyte)((pixel.a & 0x80) | (pixel.r >> 1) | (pixel.g >> 6));
}

void pack8(const ref Pixel pixel, ubyte[] buffer){
    uint grey = (pixel.r + pixel.g + pixel.b)/3;
    buffer[0] = cast(ubyte)(grey);
}
