/**
 * Integration test for compressed images.
 * The tests reads compressed images and compares them to their uncompressed version.
 */
 
import std.stdio;
import dunit.toolkit;
import tga;

void checkCompressedRead(string normalFilename, string compressedFilename){
    Image normalImg = readImage(File(normalFilename));
    Image compressedImg = readImage(File(compressedFilename));

    assertEqual(normalImg.pixels, compressedImg.pixels, "RLE reading failed for file " ~ compressedFilename);
}


unittest {
    immutable filenames = [
        "grey_8",
        "truecolor_16",
        "truecolor_24",
        "truecolor_32"
    ];
    
    foreach(filename; filenames){
        writeln("Testing RLE read: ", filename);
        checkCompressedRead(
                "resources/" ~ filename ~ ".tga",
                "resources/" ~ filename ~ "_rle.tga"
        );
    }
}
