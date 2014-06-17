module tga.model.validation;

import std.algorithm, std.conv, std.exception, std.traits;
import tga.model.types, tga.model.utils;


pure void validate(const ref Image image){
    validate(image.header);

    enforce(
        image.id.length < 256,
        "Image ID exceeds 255 bytes"
    );

    enforce(
        image.id.length == image.header.idLength,
        "Image ID size doesn't match size from header"
    );

    enforce(
        image.colorMap.length < ushort.max,
        "Image color map exceeds maximum length"
    );

    enforce(
        image.colorMap.length == image.header.colorMapLength - image.header.colorMapOffset,
        "Image color map size doesn't match size from header"
    );

    enforce(
        image.pixels.length == image.header.width * image.header.height,
        "Image pixel count doesn't match dimensions from header"
    );
}


pure void validate(const ref Header header){

    if(isColorMapped(header)) {
        enforce(
            header.colorMapType == ColorMapType.PRESENT,
            "Color-mapped image contains no color map"
        );

        enforce(
            header.colorMapDepth != ColorMapDepth.NOT_PRESENT 
                && header.colorMapDepth.among(EnumMembers!ColorMapDepth),
            "Invalid color map pixel depth: " ~ header.colorMapDepth.text
        );
    }

    enforce(
        header.colorMapDepth.among(EnumMembers!ColorMapDepth),
        "Invalid color map pixel depth: " ~ header.colorMapDepth.text
    );

    enforce(
        header.colorMapOffset <= header.colorMapLength,
        "Invalid color map size (offset > length)"
    );

    enforce(
        header.pixelDepth.among(EnumMembers!PixelDepth),
        "Invalid pixel depth: " ~ header.pixelDepth.text
    );
}

