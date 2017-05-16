module stringbuffer;

/** A super simple string buffer that will free its string if its gets out of
scope. To use it as a OutputRange use the value returned from the writer
method. getData will return a string that points to the data stored in the
StringBuffer. If the StringBuffer gets cleared up the string returned by
getData can no longer be used.
*/
struct StringBufferImpl(int stackLen) {
	import core.memory : GC;
	char[stackLen] stack;
	char* overflow = null;
	size_t capacity = stackLen;
	size_t length;
	bool copied;

	~this() {
		if(this.overflow !is null) {
			GC.free(cast(void*)this.overflow);
		}
	}

	struct OutputRange {
		StringBufferImpl!(stackLen)* buf;

		void put(const(char) c) @safe {
			this.buf.insertBack(c);
		}

		void put(dchar c) @safe {
			this.buf.insertBack(c);
		}

		void put(const(char)[] s) @safe {
			this.buf.insertBack(s);
		}

		void put(string s) @safe {
			this.buf.insertBack(s);
		}
	}

	OutputRange writer() {
		return OutputRange(&this);
	}

	private void putImpl(const(char) c) @trusted {
		if(this.length < stackLen) {
			this.stack[this.length++] = c;
		} else {
			if(this.length + 1 >= this.capacity || this.overflow is null) {
				this.grow();
				assert(this.overflow !is null);
			}
			this.overflow[this.length++] = c;
		}
	}

	private void grow() @trusted {
		this.capacity *= 2;
		this.overflow = cast(char*)GC.realloc(this.overflow, this.capacity);
		this.copy();
	}

	private void copy() @trusted {
		if(!this.copied) {
			for(size_t i = 0; i < stackLen; ++i) {
				this.overflow[i] = this.stack[i];
			}
			this.copied = true;
		}
	}

	void insertBack(const(char) c) @safe {
		this.putImpl(c);
	}

	void insertBack(dchar c) @safe {
		import std.utf : encode;
		char[4] encoded;
		size_t len = encode(encoded, c);
		this.insertBack(encoded[0 .. len]);
	}

	void insertBack(const(char)[] s) @trusted {
		if(s.length + this.length < stackLen) {
			for(size_t i = 0; i < s.length; ++i) {
				this.stack[this.length++] = s[i];
			}
		} else {
			while(s.length + this.length >= this.capacity 
					|| this.overflow is null) 
			{
				this.grow();
				assert(this.overflow !is null);
			}
			this.copy();
			for(size_t i = 0; i < s.length; ++i) {
				this.overflow[this.length++] = s[i];
			}
		}
	}

	void insertBack(string s) @safe {
		this.insertBack(cast(const(char)[])s);
	}

	void removeAll() @safe {
		this.length = 0;
		this.copied = false;
	}

	T getData(T = string)() @system {
		if(this.length >= stackLen) {
			return cast(T)this.overflow[0 .. this.length];
		} else {
			return cast(T)this.stack[0 .. this.length];
		}
	}
}

///
alias StringBuffer = StringBufferImpl!512;

unittest {
	StringBuffer buf;
	buf.insertBack('c');
	buf.insertBack("c");

	assert(buf.getData() == "cc");

	for(int i = 0; i < 2048; ++i) {
		buf.insertBack(cast(dchar)'c');
	}

	for(int i = 0; i < 2050; ++i) {
		assert(buf.getData()[i] == 'c');
	}
}

unittest {
	StringBuffer buf;
	buf.insertBack('ö');
	assert(buf.getData() == "ö");

	buf.writer().put('ö');
	assert(buf.getData() == "öö");
}

unittest {
	StringBuffer buf;
	for(int i = 0; i < 1028; ++i) {
		buf.insertBack('a');
	}

	auto s = buf.getData();
	for(int i = 0; i < s.length; ++i) {
		assert(s[i] == 'a');
	}
}

unittest {
	import std.range.primitives : isOutputRange;
	static assert(isOutputRange!(typeof(StringBuffer.writer()), char));
}

unittest {
	import std.format : formattedWrite;

	StringBuffer buf;
	formattedWrite(buf.writer(), "%d", 42);
	assert(buf.getData() == "42");
}

unittest {
	import std.format : formattedWrite;

	StringBuffer buf;
	auto w = buf.writer();
	formattedWrite(w, "foobar %d", 10);
	assert(buf.getData() == "foobar 10");
}

unittest {
	StringBuffer buf;
	auto w = buf.writer();
	w.put('a');
	assert(buf.getData() == "a");
	assert(buf.getData!(byte[])() == cast(byte[])"a");

	w.put("fo");
	assert(buf.getData!(ubyte[])() == cast(ubyte[])"afo");
}

unittest {
	string s = "0123456789";
	string l;
	for(int i = 0; i < 1026; ++i) {
		l ~= s;
	}

	StringBuffer buf;
	buf.insertBack(l);

	string ls = buf.getData();
	for(int i = 0; i < ls.length; ++i) {
		assert(ls[i] == ('0' + (i % 10)));
	}
}

unittest {
	alias SmallStringBuf = StringBufferImpl!10;

	SmallStringBuf buf;
	assert(buf.overflow is null);
	buf.insertBack("0123456789");
	buf.insertBack("0123456789");
	assert(buf.overflow !is null);
	buf.removeAll();
	assert(buf.overflow !is null);
	assert(buf.length == 0);
	assert(buf.copied == false);

	buf.insertBack("543210");
	assert(buf.length == 6);
	assert(buf.overflow !is null);
	assert(buf.overflow[0 .. 20] == "01234567890123456789");
	buf.insertBack("98765432109876543210");

	assert(buf.overflow !is null);
	assert(buf.length == 26);
	assert(buf.copied == true);
	assert(buf.getData() == "54321098765432109876543210", buf.getData());
}
