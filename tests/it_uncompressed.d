/**
 * Integration test for uncompressed images.
 * The tests reads the images and then saves them. The checksums must be the same.
 */
 
import std.stdio;
import dunit.toolkit;
import tga;

ubyte[4] crc32Of(string filename){
    import std.digest.crc: crc32Of;
    import std.file: read;
    return crc32Of(cast(ubyte[])(read(filename)));
}

void checkUncompressedReadWrite(string filename){
    immutable OUTPUT_FILE = "resources/output.tga";
    
    File file = File(filename);
    Image img = readImage(file);
    
    File outFile = File(OUTPUT_FILE, "wb");
    scope(exit) std.file.remove(OUTPUT_FILE);
    
    writeImage(outFile, img);
    outFile.close();
    
    auto crc  = crc32Of(filename);
    auto crc2 = crc32Of(OUTPUT_FILE);
    assertEqual(crc2, crc, "CRC mismatch for file " ~ filename);
}


unittest {
    immutable filenames = [
        "grey_8",
        "truecolor_16",
        "truecolor_24",
        "truecolor_32"
    ];
    
    foreach(filename; filenames){
        writeln("Testing read/write: ", filename);
        checkUncompressedReadWrite("resources/" ~ filename ~ ".tga");
    }
}
