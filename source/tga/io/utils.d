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

ubyte[] rawRead(File file, uint bytes){
	return file.rawRead(new ubyte[](bytes));
}

T sliceToNative(T)(ubyte[] bytes){
	return 0; //TODO implement
}

//private string generateSwitch(string s, int[] cases) {
//    string result = "switch("~s~"){"

//    for(kase; cases){
//    	result ~= "case " ~ std.conv.to!string(kase)~ ": int " ~ M1 ~ "; }";	
//    }

//    result ~= "}"     
//    return result;
//}