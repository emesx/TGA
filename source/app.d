import std.stdio;
import tga;

void main(){
	File file = File("tests/targa_24_unmapped_compressed.tga");
	
	writeln("TGA demo\t", file);	
    Image img = readImage(file);

    writeln(img.header, "\n\n");


	File outFile = File("tests/out.tga", "wb");
	//img.header.pixelDepth = 24;
	img.header.imageType = ImageType.COMPRESSED_TRUE_COLOR;
	writeImage(outFile, img);
}