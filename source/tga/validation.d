module tga.validation;

import std.algorithm, std.exception;
import tga.model;

void validateHeader(in Header header){
    enforce([0, 8, 16, 24, 32].canFind(header.colorMapDepth), "Invalid color map pixel depth");
    enforce(header.colorMapOffset <= header.colorMapLength, "Invalid color map size");

    enforce([8, 16, 24, 32].canFind(header.pixelDepth), "Invalid pixel depth");
}