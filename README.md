# TGA

TARGA image format support for the [D](http://dlang.org) programming language.

The library provides simple data types (`Pixel`, `Image` etc.) that might come in handy whenever image processing or synthesis is required. A set of functions to manipulate those types (I/O, transforms and more) is also included.

The library currently supports any combination of the following:

- grayscale, color-mapped and true-color images,
- 8, 16, 24 and 32 bit color depth,
- raw and RLE format.
- image origin, pixel order.

## Installation

The project is built using [dub](http://code.dlang.org) and can be used as a package dependency:

    {
        "dependencies": {
            "tga" : ">=0.1.0"
        }
    }

## Usage
Basic usage includes reading images, manipulating the pixel data, saving the image in a specified format or creating an image entirely from scratch.

**Reading and processing image**

    import tga;
    
    File inFile = File("input.tga");
    Image img = readImage(inFile);
    
    /* process the image in some way */
    process(img.pixels, img.header.width, img.header.height);
    
    File outFile = File("output.tga");
    writeImage(outFile, img);


**Generating an image**

    import tga;
    
    /* generate pixels in some way */
    Pixel[] pixels = generateImage(width, height);
    
    Image img = createImage(pixels, width, height, ImageType.COMPRESSED_TRUE_COLOR, pixelBitDepth);
    
    File outFile = File("output.tga");
    writeImage(outFile, img);


## TODOs
- support for TARGA Developer Area
