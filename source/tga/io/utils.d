module tga.io.utils;

import std.algorithm, std.bitmanip, std.stdio, std.traits;

package:

T read(T)(File file)/+ if(isNumeric!T)+/{
    ubyte[T.sizeof] bytes;
    file.rawRead(bytes[]);
    return cast(T)(bytes);
}

void write(T)(File file, T t)/+ if(isNumeric!T)+/{
    ubyte[T.sizeof] bytes = cast(ubyte[])(cast(void*)&t)[0..T.sizeof];
    file.rawWrite(bytes);
}

T sliceToNative(T)(ubyte[] slice) if(isNumeric!T) {
    const uint s = T.sizeof,
               l = min(cast(uint)s, slice.length);

    ubyte[s] padded;
    padded[0 .. l] = slice[0 .. l];	

    return littleEndianToNative!T(padded);
}

void nativeToSlice(T)(T t, size_t size, ubyte[] slice) if(isNumeric!T) {
    const uint l = min(cast(uint)T.sizeof, size);

    slice[0 .. size] = 0;
    slice[0 .. l] = nativeToLittleEndian!T(t)[0 .. l];
}
