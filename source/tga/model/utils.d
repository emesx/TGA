module tga.model.utils;

import std.algorithm;
import tga.model.types, tga.model.validation;


pure bool hasAlpha(in Image image){
	return [16, 32].canFind(image.header.pixelDepth);
}

pure bool isTrueColor(in Image image){
	return [ImageType.UNCOMPRESSED_TRUE_COLOR, ImageType.COMPRESSED_TRUE_COLOR].canFind(image.header.imageType);
}

pure bool isColorMapped(in Image image){
	return [ImageType.UNCOMPRESSED_MAPPED, ImageType.COMPRESSED_MAPPED].canFind(image.header.imageType);
}

pure bool isGrayScale(in Image image){
	return [ImageType.UNCOMPRESSED_GRAYSCALE, ImageType.COMPRESSED_GRAYSCALE].canFind(image.header.imageType);
}

/** Check if origin is bottom-left */
pure bool isUpsideDown(in Image image){
	return isUpsideDown(image.header);
}

pure bool isUpsideDown(in Header header){
	return (header.imageDescriptor & 0x20) == 0;
}

/** Check if lines store pixels right to left */
pure bool isRightToLeft(in Image image){
	return isRightToLeft(image.header);
}

pure bool isRightToLeft(in Header header){
	return (header.imageDescriptor & 0x10) != 0;
}




/** Apply origin settings to the image pixels */
void applyOrigin(in Header header, Pixel[] pixels){
    immutable h = header.height,
              w = header.width;

    if(header.isUpsideDown())
        foreach(uint y; 0 .. h/2) {
            Pixel[] row1 = pixels[y*w .. (y+1)*w];
            Pixel[] row2 = pixels[(h-1-y)*w .. (h-y)*w];
            std.algorithm.swapRanges(row1,row2);
        }

    if(header.isRightToLeft())
        foreach(uint y; 0 .. h) {
            Pixel[] row = pixels[y*w .. (y+1)*w];
            std.algorithm.reverse(row);
        }
}


void synchronizeImage(ref Image image){
	validate(image);
	image.header.idLength = cast(ubyte)(image.id.length);
	applyOrigin(image.header, image.pixels);

}