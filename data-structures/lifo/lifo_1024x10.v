module lifo_1024x10 (
	clock, 
	data, // value to add to stack
	rdreq, // 1 = remove the oldest entry on this clock edge (pop)
	sclr, // synchronous clear (active high)
	wrreq, // 1 = add data on this clock edge (push)
	empty, 
	full, 
	q, // the value that was read
	usedw); // number of entries in the queue

endmodule