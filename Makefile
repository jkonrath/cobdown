COBC ?= cobc
COBCFLAGS ?= -x -free

.PHONY: all clean run-sample

all: cobdown

cobdown: cobdown.cob
	$(COBC) $(COBCFLAGS) -o $@ $<

run-sample: cobdown
	printf '%s\n%s\n' 'sample.md' 'sample.html' | ./cobdown

clean:
	rm -f cobdown sample.html
