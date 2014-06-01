module tga.io.writers;

import std.stdio;

import tga.model;
import tga.io.utils;

alias ImageWriterFunc = void function(File, ref Image);
alias PixelWriterFunc = void function(File, ref Pixel);


void writeImage(File file, ref Image image){
	writeHeader(file, image.header);

	auto writer = imageWriterFuncMap[image.header.imageType];
	writer(file, image);
}

private {
	void writeHeader(File file, in Header header){
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
}

private {

	void writeUncompressed(File file, ref Image image){
 		auto pixelWriter = pixelWriterFuncMap[image.header.pixelDepth];

	    foreach(ref Pixel p; image.pixels) {
			pixelWriter(file, p);
		}
	}

	void writeCompressed(File file, ref Image image){
		auto pixelWriter = pixelWriterFuncMap[image.header.pixelDepth];

		Pixel last   = image.pixels[0];
		ubyte length = 1;
		bool  duringRLE  = true;
		uint  chunkStart = 0;

		void writeNormal(Pixel[] pixels){
			if(pixels.length <= 0)
				return;

			write(file, cast(ubyte)((pixels.length-1) & 0x7F));
			
			foreach(ref Pixel p; pixels)
				pixelWriter(file, p);
		}

		void writeRLE(ref Pixel pixel, ubyte times){
			if(times <= 0)
				return;

			write(file, cast(ubyte)((times-1) | 0x80));
			pixelWriter(file, pixel);
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


    enum imageWriterFuncMap = [
        ImageType.UNCOMPRESSED_TRUE_COLOR: &writeUncompressed,
        ImageType.COMPRESSED_TRUE_COLOR:   &writeCompressed
    ];
}

private {

	void write32bit(File file, ref Pixel pixel){
		write(file, pixel.b);
		write(file, pixel.g);
		write(file, pixel.r);
		write(file, pixel.a);
	}

	void write24bit(File file, ref Pixel pixel){
		write(file, pixel.b);
		write(file, pixel.g);
		write(file, pixel.r);
	}

	void write16bit(File file, ref Pixel pixel){
		ubyte[2] chunk;

		chunk[0] = ((pixel.g & 0x38) << 2) | (pixel.b >> 3);
		chunk[1] = (pixel.a & 0x80) | ((pixel.r & 0xF8) >> 1) | (pixel.g & 0xC0 >> 6);

		write(file, chunk[0]);
		write(file, chunk[1]);
	}

    enum pixelWriterFuncMap = [
        32: &write32bit,
        24: &write24bit,
        16: &write16bit
    ];

}
