module tga.model;

enum ColorMapType : ubyte { 
    NOT_PRESENT = 0,
    PRESENT = 1
};

enum ImageType : ubyte {
    NO_DATA = 0,
    UNCOMPRESSED_MAPPED = 1,
    UNCOMPRESSED_TRUE_COLOR = 2,
    UNCOMPRESSED_GRAYSCALE = 3,
    COMPRESSED_MAPPED = 9,
    COMPRESSED_TRUE_COLOR = 10,
    COMPRESSED_GRAYSCALE = 11
};


struct Header {
    ubyte           idLength;
    ColorMapType    colorMapType;
    ImageType       imageType;
    ushort          colorMapOffset;
    ushort          colorMapLength;
    ubyte           colorMapDepth;		// bits per pixel
    ushort          xOrigin;
    ushort          yOrigin;
    ushort          width;
    ushort          height;
    ubyte           pixelDepth;			// bits per pixel
    ubyte           imageDescriptor;
}

struct Pixel {
    ubyte[4] bytes;

    @property ref ubyte r() { return bytes[0]; }
    @property ref ubyte g() { return bytes[1]; }
    @property ref ubyte b() { return bytes[2]; }
    @property ref ubyte a() { return bytes[3]; }
}

struct Image {
    Header header;
    Pixel[] pixels;
}
