COBC ?= cobc
COBCFLAGS ?= -x -free

.PHONY: all clean run-sample benchmark-commonmark benchmark-commonmark-basic

all: cobdown

cobdown: cobdown.cob
	$(COBC) $(COBCFLAGS) -o $@ $<

run-sample: cobdown
	printf '%s\n%s\n' 'sample.md' 'sample.html' | ./cobdown

benchmark-commonmark: cobdown
	python3 scripts/benchmark_commonmark.py --write-failures-dir benchmark-results/commonmark

benchmark-commonmark-basic: cobdown
	python3 scripts/benchmark_commonmark.py --basic-only --write-failures-dir benchmark-results/basic

clean:
	rm -f cobdown sample.html
