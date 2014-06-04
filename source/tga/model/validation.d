module tga.model.validation;

import std.algorithm, std.conv, std.exception;
import tga.model.types;


pure void validate(in Image image){
	enforce(
		image.id.length < 256,
		"Image ID exceeds 255 bytes"
	);

	validate(image.header);
}


pure void validate(in Header header){
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

