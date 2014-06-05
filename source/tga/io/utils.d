module tga.io.utils;

import std.bitmanip, std.stdio, std.traits;

T read(T)(File file) if(isNumeric!T){
    const auto s = T.sizeof;
    ubyte[s] bytes = file.rawRead(new ubyte[](s));
    return littleEndianToNative!T(bytes);
}

void write(T)(File file, T t) if(isNumeric!T){
    const auto s = T.sizeof;
    ubyte[s] bytes = nativeToLittleEndian!T(t);
    file.rawWrite(bytes);
}

ubyte[] rawRead(File file, uint bytes){
	return file.rawRead(new ubyte[](bytes));
}

T sliceToNative(T)(ubyte[] slice) if(isNumeric!T) {
    auto min = (T t1, T t2) => (t1 <= t2) ? t1 : t2;

	const uint s = T.sizeof,
               l = min(cast(uint)s, slice.length);

    ubyte[s] padded;
    padded[0 .. l] = slice[0 .. l];	

    return littleEndianToNative!T(padded);
}