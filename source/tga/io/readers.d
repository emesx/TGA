module tga.io.readers;

import std.exception, std.stdio;
import tga.model, tga.validation, tga.io.utils;

alias ImageReaderFunc = Pixel[] function(File, in Header);
alias PixelReaderFunc = Pixel function(ubyte[]);

Image readImage(File file){
    Header header = readHeader(file);
    
    if(header.imageDescriptor & 0x20){
        debug writeln("origin is top left");
    } else {
        debug writeln("origin is bottom left ");
    }

    if(header.imageDescriptor & 0x10) {
        debug writeln("pixels go right to left");
    } else {
        debug writeln("pixels go left to right");
    }

            
    validateHeader(header);

    ubyte[] identification = readIdentification(file, header);
    Pixel[] colorMap = readColorMap(file, header);
    Pixel[] pixels =  imageReaderFuncMap[header.imageType](file, header);

    return Image(header, identification, pixels);
}

private {
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

    ubyte[] readIdentification(File file, in Header header){
        if(header.idLength)
            return file.rawRead(new ubyte[](header.idLength));
        else
            return [];
    }

    Pixel[] readColorMap(File file, in Header header){
        if(header.colorMapType == ColorMapType.NOT_PRESENT)
            return [];

        file.seek(header.colorMapOffset * (header.colorMapDepth / 8) , SEEK_CUR);

        auto pixelReader = pixelReaderFuncMap[header.colorMapDepth];
        Pixel[] colorMap = new Pixel[](header.colorMapLength);

        foreach(uint i; 0 .. header.colorMapLength){ // TODO till colorMapLenth - colorMapOffset maybe?
            ubyte[] bytes = file.rawRead(new ubyte[](header.colorMapDepth / 8));
            colorMap[i] = pixelReader(bytes);
        }

        return colorMap;
    }
}


private {
    Pixel[] readUncompressed(File file, in Header header){
        Pixel[] pixels = new Pixel[](header.height * header.width);

        auto pixelReader = pixelReaderFuncMap[header.pixelDepth];

        foreach(uint i; 0 .. header.height * header.width) {
            ubyte[] bytes = file.rawRead(new ubyte[](header.pixelDepth / 8));
            pixels[i] = pixelReader(bytes);
        }

        return pixels;
    }

    Pixel[] readCompressed(File file, in Header header){
        Pixel[] pixels = new Pixel[](header.height * header.width);

        auto pixelReader = pixelReaderFuncMap[header.pixelDepth];

        uint i = 0;
        while( i < header.height * header.width) {
            ubyte[] bytes = file.rawRead(new ubyte[](1 + header.pixelDepth / 8));
            int repetion = bytes[0] & 0x7F;
            
            pixels[i] = pixelReader(bytes[1 .. $]);
            i++;

            /* RLE */
            if(bytes[0] & 0x80){   
                for (uint j=0; j<repetion; j++, i++) {
                    pixels[i] = pixelReader(bytes[1 .. $]);
                }
            }

            /* Normal */
            else {
                for (uint j=0; j<repetion; j++, i++) {
                    bytes = file.rawRead(new ubyte[](header.pixelDepth / 8));
                    pixels[i] = pixelReader(bytes);
                }
            }          
        }

        return pixels; 
    }

 
    Pixel[] readUncompressedMapped(File file, in Header header, Pixel[] pixelMap){
        Pixel[] pixels = new Pixel[](header.height * header.width);

        auto pixelReader = pixelReaderFuncMap[header.pixelDepth];

        foreach(uint i; 0 .. header.height * header.width) {
            ubyte[] bytes = file.rawRead(new ubyte[](header.pixelDepth / 8));
            uint mapIndex = 0;// littleEndianToNative!uint(bytes);
            pixels[i] = pixelMap[mapIndex];
        }

        return pixels;
    }


    enum imageReaderFuncMap = [
        ImageType.UNCOMPRESSED_TRUE_COLOR: &readUncompressed,
        ImageType.COMPRESSED_TRUE_COLOR:   &readCompressed
    ];
}


private {
    Pixel read32bit(ubyte[] chunk){
        Pixel pixel;
        pixel.r = chunk[2];
        pixel.g = chunk[1];
        pixel.b = chunk[0];
        pixel.a = chunk[3];
        return pixel;
    }

    Pixel read24bit(ubyte[] chunk){
        Pixel pixel;
        pixel.r = chunk[2];
        pixel.g = chunk[1];
        pixel.b = chunk[0];
        pixel.a = 0xFF;
        return pixel;
    }

    Pixel read16bit(ubyte[] chunk){
        Pixel pixel;
        pixel.r = (chunk[1] & 0x7C) << 1;
        pixel.g = ((chunk[1] & 0x03) << 6) | ((chunk[0] & 0xE0) >> 2);
        pixel.b = (chunk[0] & 0x1F) << 3;
        pixel.a = (chunk[1] & 0x80) ? 0xFF : 0;
        return pixel;
    }

    Pixel read8bit(ubyte[] chunk){
        Pixel pixel;
        pixel.r = pixel.g = pixel.b = chunk[0];
        pixel.a = 255;
        return pixel;
    }

    enum pixelReaderFuncMap = [
        32: &read32bit,
        24: &read24bit,
        16: &read16bit,
        8: &read8bit
    ];
}
