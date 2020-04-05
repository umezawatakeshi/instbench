all: instbench

asm.cpp: gen_asm.pl
	perl $^ > $@

instbench: instbench.o asm.o
	${CXX} -o $@ $^

CXXFLAGS += -masm=intel

CLEANFILES = instbench *.exe *.o asm.cpp

clean:
	rm -f ${CLEANFILES}

.PHONY: clean
