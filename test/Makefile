MKFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

test:
	dune clean
	cd $(MKFILE_DIR) && dune exec -- ./test_client.exe
	dune runtest
