module tga.validation;

import std.algorithm, std.conv, std.exception;
import tga.model;

void validateHeader(in Header header){
    enforce([0, 8, 16, 24, 32].canFind(header.colorMapDepth), "Invalid color map pixel depth: " ~ to!string(header.colorMapDepth));
    enforce(header.colorMapOffset <= header.colorMapLength, "Invalid color map size");

    enforce([8, 16, 24, 32].canFind(header.pixelDepth), "Invalid pixel depth: " ~ header.pixelDepth);
}