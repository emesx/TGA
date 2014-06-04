module tga.model.validation;

import std.algorithm, std.conv, std.exception;
import tga.model.types, tga.model.utils;


pure void validate(in Image image){
    validate(image.header);

	enforce(
		image.id.length < 256,
		"Image ID exceeds 255 bytes"
	);

    enforce(
        image.header.width * image.header.height == image.pixels.length,
        "Image pixel count doen't match dimensions from header"
    );
}


pure void validate(in Header header){

    if(isColorMapped(header))
        enforce(
       	    header.colorMapType == ColorMapType.PRESENT,
            "Color-mapped image contains no color map"
        );

    enforce(
    	[0, 8, 16, 24, 32].canFind(header.colorMapDepth),
    	"Invalid color map pixel depth: " ~ to!string(header.colorMapDepth)
    );

    enforce(
    	header.colorMapOffset <= header.colorMapLength,
    	"Invalid color map size (offset > length)"
    );

    enforce(
    	[8, 16, 24, 32].canFind(header.pixelDepth),
    	"Invalid pixel depth: " ~ to!string(header.pixelDepth)
    );
}

