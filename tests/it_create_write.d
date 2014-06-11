/**
 * Integration test for creating images from scratch.
 * The test generates images, saves them and then reads them back. 
 * The contents of generated images must be equal to the saved and read ones.
 */
 
import std.file, std.stdio;
import dunit.toolkit;
import tga;

auto PIXELS =  [
    Pixel([0,0,0,255]),   Pixel([255,0,0,255]), Pixel([255,0,0,255]), Pixel([255,0,0,255]), 
    Pixel([0,255,0,255]), Pixel([0,255,0,255]), Pixel([0,255,0,255]), Pixel([0,255,0,255]),
    Pixel([0,255,0,255]), Pixel([0,255,0,255]), Pixel([0,255,0,255]), Pixel([0,255,0,255]),
    Pixel([0,0,255,255]), Pixel([0,0,255,255]), Pixel([0,0,255,255]), Pixel([255,255,255,255])
];

immutable OUTPUT_DIR = "resources/generated";

static  this() { mkdirRecurse(OUTPUT_DIR); }
static ~this() { rmdirRecurse(OUTPUT_DIR); }

void checkCreateWrite(ImageType type, uint pixelDepth){
    import std.algorithm, std.conv;

    immutable fileName = "test_" ~ to!string(type) ~ "_" ~ to!string(pixelDepth) ~ ".tga";
    immutable filePath = OUTPUT_DIR ~ "/" ~ fileName;
    writeln("Testing create: ", fileName);

    auto image = createImage(PIXELS, 4, 4, type, cast(ubyte)pixelDepth);

    {
        File outFile = File(filePath, "wb");
        scope(exit) outFile.close();
        writeImage(outFile, image);
    }
  
    File inFile = File(filePath, "rb");
    auto saved = readImage(inFile);

    assertEqual(image.header, saved.header, "Generated header differs from saved " ~ fileName);
    assertEqual(image.id, saved.id, "Generated id differs from saved " ~ fileName);

    if([24,32].canFind(pixelDepth)){ // these save pixels as-are
        assertEqual(image.colorMap, saved.colorMap, "Generated color map differs from saved " ~ fileName);
        assertEqual(image.pixels, saved.pixels, "Generated pixels differs from saved " ~ fileName);
    }
}


unittest {
    import std.typecons;

    immutable cases = [
        tuple(ImageType.UNCOMPRESSED_TRUE_COLOR, 32),
        tuple(ImageType.UNCOMPRESSED_TRUE_COLOR, 24),
        tuple(ImageType.UNCOMPRESSED_TRUE_COLOR, 16),
        
        tuple(ImageType.COMPRESSED_TRUE_COLOR, 32),
        tuple(ImageType.COMPRESSED_TRUE_COLOR, 24),
        tuple(ImageType.COMPRESSED_TRUE_COLOR, 16),
        
        tuple(ImageType.UNCOMPRESSED_MAPPED, 32),
        tuple(ImageType.UNCOMPRESSED_MAPPED, 24),
        tuple(ImageType.UNCOMPRESSED_MAPPED, 16),
        
        tuple(ImageType.COMPRESSED_MAPPED, 32),
        tuple(ImageType.COMPRESSED_MAPPED, 24),
        tuple(ImageType.COMPRESSED_MAPPED, 16),

        tuple(ImageType.UNCOMPRESSED_GRAYSCALE, 8),
        tuple(ImageType.COMPRESSED_GRAYSCALE, 8)
    ];
    
    foreach(kase; cases)
        checkCreateWrite(kase[0], kase[1]);
}

