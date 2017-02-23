StringBuffer
============

A simple stack based StringBuffer that overflows into the heap and releases
all used memory on destruction.

By default the StringBuffer can store 512 chars on the stack.
If a different number of chars on the stack is required create an
```d
alias MyStringBuffer = StringBufferImpl!1337;
```
like this.

The two important methods of the StringBuffer are writer and getData.
The method writer returns a OutputRange that can be used with formattedWrite
from std.format;
The method getData returns a string of the stored data.
No reference to the returned data from writer and getData must be used after
the associated StringBuffer is destructed.

Example
-------

```d
unittest {
	import std.format : formattedWrite;

	StringBuffer buf;
	auto w = buf.writer();
	formattedWrite(w, "foobar %d", 10);
	assert(buf.getData() == "foobar 10");
}
```
