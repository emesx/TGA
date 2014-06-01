module tga.io.readers;

import std.stdio;
import tga.model, tga.io.utils;

alias ImageReaderFunc = Image function(File, Header);
alias PixelReaderFunc = Pixel function(ubyte[]);

Image readImage(File file){
    Header header = readHeader(file);
    auto reader = imageReaderFuncMap[header.imageType];
	return reader(file, header);
}

private {
    Header readHeader(File file){
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
}


private {
    Image readUncompressed(File file, Header header){
        file.seek(header.idLength + header.colorMapType * header.colorMapLength, SEEK_CUR);

        Pixel[] pixels = new Pixel[](header.height * header.width);
        Image image = {header, pixels};

        auto pixelReader = pixelReaderFuncMap[header.pixelDepth];

        foreach(uint i; 0 .. header.height * header.width) {
            ubyte[] bytes = file.rawRead(new ubyte[](header.pixelDepth / 8));
            pixels[i] = pixelReader(bytes);
        }

        return image;
    }

   Image readCompressed(File file, Header header){
       file.seek(header.idLength + header.colorMapType * header.colorMapLength, SEEK_CUR);

        Pixel[] pixels = new Pixel[](header.height * header.width);
        Image image = {header, pixels};

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

        return image;
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

    enum pixelReaderFuncMap = [
        32: &read32bit,
        24: &read24bit,
        16: &read16bit
    ];
}
