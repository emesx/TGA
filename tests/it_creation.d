/**
 * Integration test for creating images from scratch.
 */
 
import std.stdio;
import dunit.toolkit, dunit.output.console;
import tga;


unittest {

    auto pixels =  [
        Pixel([0,0,0,255]), Pixel([255,0,0,255]), Pixel([255,0,0,255]), 
        Pixel([0,255,0,255]), Pixel([0,255,0,255]), Pixel([0,255,0,255]), 
        Pixel([0,0,255,255]), Pixel([0,0,255,255]), Pixel([255,255,255,255])
    ];

    auto image = createImage(pixels, 3, 3, ImageType.COMPRESSED_MAPPED, 32 );

    File outFile = File("resources/output_scratch.tga", "wb");
    scope(exit) outFile.close();
    
    writeImage(outFile, image);
}
