module tga.io.writers;

import std.algorithm, std.conv, std.range, std.stdio;
import tga.model, tga.io.utils;

/**
 * Writes the file to the disk.
 * Also updates developer fields offsets if needed.
 */
void writeImage(bool writeDeveloperField = false)(File file, ref Image image){
    validate(image);

    writeHeader(file, image);
    writeId(file, image);
    writeColorMap(file, image);

    ImageWriterMap[image.header.imageType](file, image);
    if(writeDeveloperField){
        writeDeveloperDirectory(file, image);
        writeDeveloperArea(file, image);
        writeFooter(file, image);
    }
}


package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

void writeHeader(File file, const ref Image image){
    /*with(image.header){
        write(file, idLength);
        write(file, colorMapType);
        write(file, imageType);
        write(file, colorMapOffset);
        write(file, colorMapLength);
        write(file, colorMapDepth);
        write(file, xOrigin);
        write(file, yOrigin);
        write(file, width);
        write(file, height);
        write(file, pixelDepth);
        write(file, imageDescriptor);
    }*/
    write(file, image.header);
}

void writeDeveloperArea(File file, ref Image image){
    foreach(entry; image.developerArea)
        file.rawWrite(entry.data);
}
void writeDeveloperDirectory(File file, ref Image image){
    image.footer.developerAreaOffset = cast(uint)file.tell();
    uint offset = cast(uint)(image.footer.developerAreaOffset + (image.developerDirectory.length * DevAreaTag.sizeof));
    foreach(ref DevAreaTag entry; image.developerDirectory){
        entry.offset = offset;
        offset += entry.fieldSize;
    }
    file.rawWrite(cast(ubyte[])(cast(void[])image.developerDirectory));
}
void writeFooter(File file, ref Image image){
    write(file, image.footer);
}

void writeId(File file, const ref Image image){
    if(image.id.length > 0)
        file.rawWrite(image.id);
}


void writeColorMap(File file, const ref Image image){
    /*if(!isColorMapped(image.header))
        return;

    ubyte[PixelDepth.max/8] buffer;

    auto pixelByteDepth = image.header.colorMapDepth/8;
    auto pack  = PixelPackerMap[image.header.colorMapDepth];

    foreach(_ ; 0 .. image.header.colorMapOffset){
        file.rawWrite(buffer[0 ..pixelByteDepth]);
    }

    foreach(ref p; image.colorMap){
        pack(p, buffer);
        file.rawWrite(buffer[0 .. pixelByteDepth]);
    }*/
    file.rawWrite(image.colorMap);
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
    /*ubyte[PixelDepth.max/8] buffer;

    auto pixelByteDepth = image.header.pixelDepth/8;
    auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                    ? (const ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), pixelByteDepth, buffer)
                    : (const ref Pixel p) => pack(p, buffer);

    foreach(ref p; image.pixels){
        handle(p);
        file.rawWrite(buffer[0 .. pixelByteDepth]);
    }*/
    file.rawWrite(image.pixels);
}


void writeCompressed(ref File file, ref Image image){
    auto pixelByteDepth = image.header.pixelDepth/8;
    ubyte[PixelDepth.max/8] buffer;
    
    /+auto pack = PixelPackerMap[image.header.pixelDepth];
    auto handle = (isColorMapped(image.header))
                        ? (const ref Pixel p) => nativeToSlice(indexInColorMap(image.colorMap, p), pixelByteDepth, buffer)
                        : (const ref Pixel p) => pack(p, buffer);+/
    
    //auto writePixel = (const ref Pixel p) { file.rawWrite(buffer[0 .. pixelByteDepth]); };
    switch(image.header.pixelDepth){
        case PixelDepth.BPP8:
            ubyte[] pixels = image.pixels[];
            while(pixels.length) {
                // Find the first occurrence of two equal pixels next to each other
                auto nextPixels = pixels.findAdjacent;

                    // Everything before that point should be written as raw packets.
                // Max packet size is 128 pixels so make chunks of that size
                foreach(const ref packet; pixels[0 .. $ - nextPixels.length].chunks(128)) {
                    write(file, to!ubyte(packet.length-1));
                    foreach(const ref p; packet)
                        write(file, p);
                    }

                // If there are more pixels in the image, the next pixels can be RLE encoded
                if(nextPixels.length){
                    // Find the point at which the pixel data changes
                    pixels = nextPixels.find!"a!=b"(nextPixels[0]);

                    // Everything before that point should be written as RLE packets
                    foreach(const ref packet; nextPixels[0 .. $ - pixels.length].chunks(128)){
                        write(file, to!ubyte(packet.length-1 | 0x80));
                        write(packet[0]);
                    }
                }
                else break;
            }
            break;
        case PixelDepth.BPP16:
            Pixel16Bit[] pixels = cast(Pixel16Bit[])(cast(void[])image.pixels[]);
            while(pixels.length) {
                // Find the first occurrence of two equal pixels next to each other
                auto nextPixels = pixels.findAdjacent;

                    // Everything before that point should be written as raw packets.
                // Max packet size is 128 pixels so make chunks of that size
                foreach(const ref packet; pixels[0 .. $ - nextPixels.length].chunks(128)) {
                    write(file, to!ubyte(packet.length-1));
                    foreach(const ref p; packet)
                        write(file, p);
                        //writePixel(p);

                    }

                // If there are more pixels in the image, the next pixels can be RLE encoded
                if(nextPixels.length){
                    // Find the point at which the pixel data changes
                    pixels = nextPixels.find!"a!=b"(nextPixels[0]);
    
                    // Everything before that point should be written as RLE packets
                    foreach(const ref packet; nextPixels[0 .. $ - pixels.length].chunks(128)){
                        write(file, to!ubyte(packet.length-1 | 0x80));
                        //writePixel(packet[0]);
                        write(packet[0]);
                    }
                }
                else break;
            }
            break;
        case PixelDepth.BPP24:
            Pixel24Bit[] pixels = cast(Pixel24Bit[])(cast(void[])image.pixels[]);
            while(pixels.length) {
                // Find the first occurrence of two equal pixels next to each other
                auto nextPixels = pixels.findAdjacent;

                    // Everything before that point should be written as raw packets.
                // Max packet size is 128 pixels so make chunks of that size
                foreach(const ref packet; pixels[0 .. $ - nextPixels.length].chunks(128)) {
                    write(file, to!ubyte(packet.length-1));
                    foreach(const ref p; packet)
                        write(file, p);
                        //writePixel(p);

                    }

                // If there are more pixels in the image, the next pixels can be RLE encoded
                if(nextPixels.length){
                    // Find the point at which the pixel data changes
                    pixels = nextPixels.find!"a!=b"(nextPixels[0]);
    
                    // Everything before that point should be written as RLE packets
                    foreach(const ref packet; nextPixels[0 .. $ - pixels.length].chunks(128)){
                        write(file, to!ubyte(packet.length-1 | 0x80));
                        //writePixel(packet[0]);
                        write(packet[0]);
                    }
                }
                else break;
            }
            break;
        case PixelDepth.BPP32:
            Pixel[] pixels = cast(Pixel[])(cast(void[])image.pixels[]);
            while(pixels.length) {
                // Find the first occurrence of two equal pixels next to each other
                auto nextPixels = pixels.findAdjacent;

                    // Everything before that point should be written as raw packets.
                // Max packet size is 128 pixels so make chunks of that size
                foreach(const ref packet; pixels[0 .. $ - nextPixels.length].chunks(128)) {
                    write(file, to!ubyte(packet.length-1));
                    foreach(const ref p; packet)
                        write(file, p);
                        //writePixel(p);

                    }

                // If there are more pixels in the image, the next pixels can be RLE encoded
                if(nextPixels.length){
                    // Find the point at which the pixel data changes
                    pixels = nextPixels.find!"a!=b"(nextPixels[0]);
    
                    // Everything before that point should be written as RLE packets
                    foreach(const ref packet; nextPixels[0 .. $ - pixels.length].chunks(128)){
                        write(file, to!ubyte(packet.length-1 | 0x80));
                        //writePixel(packet[0]);
                        write(packet[0]);
                    }
                }
                else break;
            }
            break;
        default: break;
    }

    
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
