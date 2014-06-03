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
		"resources/targa_24_unmapped_uncompressed.tga",
		"resources/targa_32_unmapped_uncompressed.tga"
	];
	
	foreach(filename; filenames){
		writeln("Testing ", filename);
		checkUncompressedReadWrite(filename);
	}
}

//unittest {
//	writeln("--- TEMPORARY TEST ---");
	
//	File file = File("resources/monochrome8_bottom_left.tga");
//	Image img = readImage(file);
    
//	img.header.imageDescriptor &= 0b11001111;
//	img.header.imageDescriptor |= 0b00100000;

//	File outFile = File("resources/output.tga", "wb");
//	writeImage(outFile, img);
//	outFile.close();
//}