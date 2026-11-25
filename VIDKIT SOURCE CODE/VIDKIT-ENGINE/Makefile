PROGRAM := VIDKIT.ENGINE
%.o: %.s
	cl65 --mapfile src/pv.sym -t cx16 -c -o $@ $<
$(PROGRAM): src/main.o
	cl65 --mapfile src/pv.sym -o $@ $^ -C src/cx16-asm.cfg
clean:
	$(RM) -f src/main.o $(PROGRAM) TEST.DAT
test: $(PROGRAM)
	x16emu -fsroot . -prg TEST.PRG -run
