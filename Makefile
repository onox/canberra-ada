CFLAGS  ?= -O2 -march=native

GNATMAKE    = gprbuild -dm -p
GNATCLEAN   = gprclean -q
GNATINSTALL = gprinstall
GNATPROVE   = gnatprove --cwe --pedantic -k -j0 --output-header

PREFIX ?= /usr

includedir = $(PREFIX)/include
gprdir     = $(PREFIX)/share/gpr
libdir     = $(PREFIX)/lib
alidir     = $(libdir)

installcmd = $(GNATINSTALL) -p \
	--sources-subdir=$(includedir) \
	--project-subdir=$(gprdir) \
	--lib-subdir=$(libdir) \
	--ali-subdir=$(alidir) \
	--prefix=$(PREFIX)

.PHONY: build debug clean prove ce install uninstall

build:
	$(GNATMAKE) -P tools/canberra.gpr -cargs $(CFLAGS)

debug:
	$(GNATMAKE) -P tools/canberra.gpr -XMode=debug -cargs $(CFLAGS)

clean:
	-$(GNATPROVE) --clean -P tools/canberra.gpr
	$(GNATCLEAN) -P tools/canberra.gpr
	rm -rf bin build

prove:
	$(GNATPROVE) --level=4 --prover=all --mode=check -P tools/canberra.gpr

ce:
	docker run --rm -it -v ${PWD}:/test -u $(shell id -u):$(shell id -g) -w /test alire/gnat:community-latest make

install:
	$(installcmd) -f --install-name='canberra-ada' -P tools/canberra.gpr

uninstall:
	$(installcmd) --uninstall --install-name='canberra-ada' -P tools/canberra.gpr
