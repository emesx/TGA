module tga.io.writers;

import std.stdio;
import tga.model, tga.io.utils;


void writeImage(File file, ref Image image){
    validate(image);

    auto colorMap = buildColorMap(image);
    writeColorMap(file, image.header, colorMap);

	writeHeader(file, image);
	writeId(file, image);

	ImageWriterMap[image.header.imageType](file, image, colorMap);
}


package:

/* --- Header and color map------------------------------------------------------------------------------------------ */

void writeHeader(File file, in Image image){
	auto header = &image.header;

	write(file, cast(ubyte)(image.id.length));
	write(file, isColorMapped(image.header) ? ColorMapType.PRESENT : ColorMapType.NOT_PRESENT);
	write(file, header.imageType);
	write(file, header.colorMapOffset); //TODO this should be taken from just-built color map, not from header
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


Pixel[] buildColorMap(in Image image){
    import std.algorithm : canFind;

    if(!isColorMapped(image.header))
        return [];
    
    auto colorMap = new Pixel[](1);

    foreach(const ref Pixel p; image.pixels)
        if(!colorMap.canFind(p))
            colorMap ~= p;

    return colorMap;
}


void writeColorMap(File file, in Header header, Pixel[] colorMap){
    if(header.colorMapDepth !in PixelPackerMap)
        return;

	auto pack = PixelPackerMap[header.colorMapDepth];

    foreach(ref Pixel p; colorMap) {
		pack(file, p);
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


void writeUncompressed(File file, ref Image image, Pixel[] colorMap){
	auto pack = PixelPackerMap[image.header.pixelDepth];

    foreach(ref Pixel p; image.pixels) {
		pack(file, p);
	}
}


void writeCompressed(File file, ref Image image, Pixel[] colorMap){
	auto pack = PixelPackerMap[image.header.pixelDepth];

	Pixel last   = image.pixels[0];
	ubyte length = 1;
	bool  duringRLE  = true;
	uint  chunkStart = 0;

	void writeNormal(Pixel[] pixels){
		if(pixels.length <= 0)
			return;

		write(file, cast(ubyte)((pixels.length-1) & 0x7F));
		
		foreach(ref Pixel p; pixels)
			pack(file, p);
	}

	void writeRLE(ref Pixel pixel, ubyte times){
		if(times <= 0)
			return;

		write(file, cast(ubyte)((times-1) | 0x80));
		pack(file, pixel);
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
    8  : &pack8
];


void pack32(File file, ref Pixel pixel){ //TODO packers should take pixel and return slice of ubyte
	write(file, pixel.b);
	write(file, pixel.g);
	write(file, pixel.r);
	write(file, pixel.a);
}

void pack24(File file, ref Pixel pixel){
	write(file, pixel.b);
	write(file, pixel.g);
	write(file, pixel.r);
}

void pack16(File file, ref Pixel pixel){
	ubyte[2] chunk;

	chunk[0] = ((pixel.g & 0x38) << 2) | (pixel.b >> 3);
	chunk[1] = (pixel.a & 0x80) | ((pixel.r & 0xF8) >> 1) | (pixel.g & 0xC0 >> 6);

	write(file, chunk[0]);
	write(file, chunk[1]);
}

void pack8(File file, ref Pixel pixel){
    uint grey = (pixel.r + pixel.g + pixel.b)/3;
	write(file, cast(ubyte)(grey));
}
