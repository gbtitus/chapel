var x = 1: int(8);
var y = 2: int(8);
var z = 3: int(16);

var a = x + y;
var b = x + z;

writeln("a is ", a, " (", typeToString(a.type), ")");
writeln("b is ", b, " (", typeToString(b.type), ")");
