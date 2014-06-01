module tga.io.utils;

import std.bitmanip, std.stdio, std.traits;

T read(T)(File file) if(isNumeric!T) {
    const auto s = T.sizeof;
    ubyte[s] bytes = file.rawRead(new ubyte[](s));
    return littleEndianToNative!T(bytes);
}

void write(T)(File file, T t) if(isNumeric!T){
    const auto s = T.sizeof;
    ubyte[s] bytes = nativeToLittleEndian!T(t);
    file.rawWrite(bytes);
}