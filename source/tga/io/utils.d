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

//T sliceToNative(T)(ubyte[] bytes){
//	switch(bytes.length){
//		case 1: 
//			ubyte[1] staticBytes = bytes;
//			return littleEndianToNative!T(staticBytes);
//		case 2:s
//			ubyte[2] staticBytes = bytes;
//			return littleEndianToNative!T(staticBytes);
//		case 4:
//			ubyte[4] staticBytes = bytes;
//			return littleEndianToNative!T(staticBytes);
//		default:
//			assert(false);
//	}
//}

//private string generateSwitch(string s, int[] cases) {
//    string result = "switch("~s~"){"

//    for(kase; cases){
//    	result ~= "case " ~ std.conv.to!string(kase)~ ": int " ~ M1 ~ "; }";	
//    }

//    result ~= "}"     
//    return result;
//}