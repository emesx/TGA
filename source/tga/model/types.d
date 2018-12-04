module tga.model.types;

import std.bitmanip;

struct Image {
    Header  header;
    ubyte[] id;
    /+Pixel[] colorMap;
    Pixel[] pixels;+/
    ubyte[] colorMap;
    ubyte[] pixels;
    DevAreaTag[] developerDirectory;
    DevArea[] developerArea;
    ubyte[] extensionArea;
    Footer footer;
    
    this(Header  header, ubyte[] id, ubyte[] colorMap, ubyte[] pixels){
        this.header = header;
        this.id = id;
        this.colorMap = colorMap;
        this.pixels = pixels;
    }
    this(Header  header, ubyte[] id, ubyte[] colorMap, ubyte[] pixels, Footer footer){
        this.header = header;
        this.id = id;
        this.colorMap = colorMap;
        this.pixels = pixels;
        this.footer = footer;
    }
    /**
     * Reads a single pixel. Can read both indexed and unindexed images.
     * Throws ImageBoundsException if x or y are pointing at an illegal area, ImageFormatMismatchException if the image cannot be read as indexed.
     */
    public T readPixel(T)(ushort x, ushort y){
        if(x > header.width || y > header.height)
            throw new ImageBoundsException("Image is being read out of bounds!");
        static if(T.stringof == Pixel.stringof){
            if(header.colorMapType == ColorMapType.PRESENT){
                ushort index = readPixel!ushort(x,y);
                final switch(header.colorMapDepth){
                    case ColorMapDepth.BPP8:
                        return Pixel(colorMap[index], colorMap[index], colorMap[index], colorMap[index]);
                    case ColorMapDepth.BPP16:
                        Pixel16Bit p = cast(Pixel16Bit[])(cast(void[])colorMap)[index];
                        return Pixel(p);
                    case ColorMapDepth.BPP24:
                        Pixel24Bit p = cast(Pixel24Bit[])(cast(void[])colorMap)[index];
                        return Pixel(p);
                    case ColorMapDepth.BPP32:
                        Pixel p = cast(Pixel[])(cast(void[])colorMap)[index];
                        return p;
                }
                
            }else{
                final switch(header.bitdepth){
                    case PixelDepth.BPP8:
                        ubyte p = pixels[x + (y * header.width)];
                        return Pixel(p, p, p, 0xFF);
                    case PixelDepth.BPP16:
                        Pixel16Bit p = cast(Pixel16Bit[])(cast(void[])pixels)[x + (y * header.width)];
                        return Pixel(p);
                    case PixelDepth.BPP24:
                        Pixel24Bit p = cast(Pixel24Bit[])(cast(void[])pixels)[x + (y * header.width)];
                        return Pixel(p);
                    case PixelDepth.BPP32:
                        Pixel p = cast(Pixel[])(cast(void[])pixels)[x + (y * header.width)];
                        return p;
                }
                Pixel p = cast(Pixel[])(cast(void[])pixels)[x + (y * header.width)];
                return p;
            }
        }else static if(T.stringof == ubyte.stringof){
            if(header.pixelDepth == PixelDepth.BPP8)
                return pixels[x + (y * header.width)];
            else throw new ImageFormatMismatchException("The image bitdepth doesn't allow it.");
        }else static if(T.stringof == ushort.stringof){
            if(header.pixelDepth == PixelDepth.BPP8)
                return pixels[x + (y * header.width)];
            else if(header.pixelDepth == PixelDepth.BPP16)
                return cast(ushort[])(cast(void[])pixels)[x + (y * header.width)];
            else throw new ImageFormatMismatchException("The image bitdepth doesn't allow it.");
        }else static if(T.stringof == Pixel16Bit.stringof){
            if(header.pixelDepth == PixelDepth.BPP16)
                return cast(Pixel16Bit[])(cast(void[])pixels)[x + (y * header.width)];
            else throw new ImageFormatMismatchException("The image bitdepth doesn't allow it.");
        }else static if(T.stringof == Pixel24Bit.stringof){
            if(header.pixelDepth == PixelDepth.BPP24)
                return cast(Pixel24Bit[])(cast(void[])pixels)[x + (y * header.width)];
            else throw new ImageFormatMismatchException("The image bitdepth doesn't allow it.");
        }else static assert(0,"Template argument not supported!");
    }
    /**
     * Writes a pixel.
     * Throws ImageBoundsException if x or y are pointing at an illegal area, ImageFormatMismatchException if the image cannot be written as indexed.
     */
    public void writePixel(T)(ushort x, ushort y, T pixel){
        if(x > header.width || y > header.height)
            throw new ImageBoundsException("Image is being written out of bounds!");
        static if(T.stringof == Pixel.stringof){
            if(header.colorMapType == ColorMapType.PRESENT){
                throw new ImageFormatMismatchException("Indexed bitmaps cannot be written as unindexed.");
            }else{
                if(header.bitdepth == PixelDepth.BPP32){
                    cast(Pixel[])(cast(void[])pixels)[x + (y * header.width)] = pixel;
                }else throw new ImageFormatMismatchException("Wrong pixel format used.");
            }
        }else static if(T.stringof == Pixel16Bit.stringof){
            if(header.colorMapType == ColorMapType.PRESENT){
                throw new ImageFormatMismatchException("Indexed bitmaps cannot be written as unindexed.");
            }else{
                if(header.bitdepth == PixelDepth.BPP16){
                    cast(Pixel16Bit[])(cast(void[])pixels)[x + (y * header.width)] = pixel;
                }else throw new ImageFormatMismatchException("Wrong pixel format used.");
            }
        }else static if(T.stringof == Pixel24Bit.stringof){
            if(header.colorMapType == ColorMapType.PRESENT){
                throw new ImageFormatMismatchException("Indexed bitmaps cannot be written as unindexed.");
            }else{
                if(header.bitdepth == PixelDepth.BPP24){
                    cast(Pixel24Bit[])(cast(void[])pixels)[x + (y * header.width)] = pixel;
                }else throw new ImageFormatMismatchException("Wrong pixel format used.");
            }
        }else static if(T.stringof == ubyte.stringof){
            if(header.bitdepth == PixelDepth.BPP8){
                pixels[x + (y * header.width)] = pixel;
            }else throw new ImageFormatMismatchException("Wrong pixel format used.");
        }else static if(T.stringof == ushort.stringof){
            if(header.bitdepth == PixelDepth.BPP16){
                cast(ushort[])(cast(void[])pixels)[x + (y * header.width)] = pixel;
            }else throw new ImageFormatMismatchException("Wrong pixel format used.");
            
        }else static assert(0,"Template argument not supported!");
    }
}

struct Pixel {
    union{
        ubyte[4] bytes;     /// BGRA
        uint base;          /// Direct address
    }

    @property ref auto r() inout { return bytes[2]; }
    @property ref auto g() inout { return bytes[1]; }
    @property ref auto b() inout { return bytes[0]; }
    @property ref auto a() inout { return bytes[3]; }
    @nogc this(ubyte[4] bytes){
        this.bytes = bytes;
    }
    @nogc this(ubyte r, ubyte g, ubyte b, ubyte a){
        bytes[0] = b;
        bytes[1] = g;
        bytes[2] = r;
        bytes[3] = a;
    }
    @nogc this(Pixel16Bit p){
        bytes[0] = cast(ubyte)(p.b<<3 | p.b>>2);
        bytes[1] = cast(ubyte)(p.g<<3 | p.g>>2);
        bytes[2] = cast(ubyte)(p.r<<3 | p.r>>2);
        bytes[3] = p.a ? 0xFF : 0x00;
    }
    @nogc this(Pixel24Bit p){
        bytes[0] = p.b;
        bytes[1] = p.g;
        bytes[2] = p.r;
        bytes[3] = 0xFF;
    }
}

struct Pixel16Bit {
    union{
        ushort base;        /// Direct address
        mixin(bitfields!(
            ubyte, "b", 5,
            ubyte, "g", 5,
            ubyte, "r", 5,
            bool, "a", 1,
        ));
    }
}

align(1) struct Pixel24Bit {
    ubyte[3] bytes;
    @property ref auto r() inout { return bytes[2]; }
    @property ref auto g() inout { return bytes[1]; }
    @property ref auto b() inout { return bytes[0]; }
}

align(1) struct Header {
    ubyte           idLength;           /// length in bytes
    ColorMapType    colorMapType;
    ImageType       imageType;
    ushort          colorMapOffset;     /// index of first actual map entry
    ushort          colorMapLength;     /// number of total entries (incl. skipped)
    ColorMapDepth   colorMapDepth;      /// bits per pixel (entry)
    ushort          xOrigin;
    ushort          yOrigin;
    ushort          width;
    ushort          height;
    PixelDepth      pixelDepth;         /// bits per pixel
    ubyte           imageDescriptor;    /// tTODO: make this a bitfield
}

align(1) struct Footer {
    uint            extensionAreaOffset;    /// offset of the extensionArea, zero if doesn't exist
    uint            developerAreaOffset;    /// offset of the developerArea, zero if doesn't exist
    char[16]        signature = "TRUEVISION-XFILE";   /// if equals with "TRUEVISION-XFILE", it's the new format
    char            reserved = '.';
    ubyte           terminator;             /// terminates the file

    @property bool isValid(){
        return signature == "TRUEVISION-XFILE";
    }
}

struct DevAreaTag{
    ushort          reserved;       /// number of tags in the beginning
    /**
     * Identifier tag of the developer area field.
     * Supposedly the range of 32768 - 65536 is reserved by Truevision, however there are no information on whenever it was
     * used by them or not.
     */
    ushort          tag;            
    uint            offset;         /// offset into file
    uint            fieldSize;      /// field size in bytes
}

struct DevArea{
    ubyte[] data;

    /**
     * Returns the data as a certain type (preferrably struct) if available
     */
    T get(T)(){
        if(T.sizeof == data.length){
            return cast(T)(cast(void[])data);
        }
    }
}

enum ColorMapType : ubyte { 
    NOT_PRESENT = 0,
    PRESENT     = 1
}

/**
 * Supposedly, there were other compression algorithms, but never became popular enough.
 */
enum ImageType : ubyte {
    NO_DATA                 = 0,
    UNCOMPRESSED_MAPPED     = 1,
    UNCOMPRESSED_TRUE_COLOR = 2,
    UNCOMPRESSED_GRAYSCALE  = 3,
    COMPRESSED_MAPPED       = 9,
    COMPRESSED_TRUE_COLOR   = 10,
    COMPRESSED_GRAYSCALE    = 11

}

enum ImageOrigin { 
    BOTTOM_LEFT = 0,
    TOP_LEFT    = 1
}

enum PixelOrder { 
    LEFT_TO_RIGHT = 0,
    RIGHT_TO_LEFT = 1 
}

enum PixelDepth : ubyte {
    BPP1  = 1,  /// non-standard
    BPP4  = 4,  /// non-standard
    BPP8  = 8,
    BPP16 = 16,
    BPP24 = 24,
    BPP32 = 32
}

enum ColorMapDepth : ubyte {
    NOT_PRESENT = 0,
    BPP8  = 8,
    BPP16 = 16,
    BPP24 = 24,
    BPP32 = 32
}
/**
 * Thrown if image is being read or written out of bounds.
 */
class ImageBoundsException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
/**
 * Thrown if image format doesn't match.
 */
class ImageFormatMismatchException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
/**
 * Thrown if requested type of developer area type's size has a mismatch.
 */
class DeveloperFieldException : Exception{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}