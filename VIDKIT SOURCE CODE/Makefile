# Makefile -- builds VIDKIT-A000.BIN.  Same steps as BUILDVIDKIT.BAS / BUILDVIDKIT.ps1
#
#   make                          build everything
#   make clean                    remove generated files
#   make PROG8JAR=/path/prog8.jar use (and remember in P8JARPATH) this prog8 jar
#
# Needs: GNU make, a POSIX shell (Linux/macOS, or MSYS2/Git-Bash on Windows),
#        java, 64tass, cc65 (cl65) -- the same tools BUILDVIDKIT uses.
#
# Layout of VIDKIT-A000.BIN (each part padded with zero bytes to its slot):
#   VIDKIT-B1.bin   8192   (prog8 bank 1)
#   VIDKIT.ENGINE   2560
#   VIDKIT-B2.bin   5632   (prog8 bank 2)
#   SPIVID.ENGINE   5120
#   VIDKIT-B3.bin   as is  (prog8 bank 3, not padded)
#
# Afterwards VIDKIT.Z = lzsa -r -f2 VIDKIT-A000.BIN VIDKIT.Z, and the new
# VIDKIT-A000.BIN / VIDKIT.Z are copied into the example folders (see 'install').
# Needs lzsa on the PATH.

SHELL := /bin/sh

# prog8 jar: PROG8JAR on the command line / environment, else the first line of P8JARPATH
ifeq ($(origin PROG8JAR),undefined)
PROG8JAR := $(shell tr -d '\r' < P8JARPATH 2>/dev/null | head -n 1)
endif

.PHONY: all clean check-jar tramp b1 b2 b3 engines library compress install

all: check-jar tramp b1 b2 b3 engines library compress install

check-jar:
	@case "$(PROG8JAR)" in \
	  *.jar|*.JAR) [ -f "$(PROG8JAR)" ] && ok=1 ;; \
	esac; \
	if [ -z "$$ok" ]; then \
	  echo; echo "prog8 JAR not found !"; echo "Can't continue !"; \
	  echo "Use:  make PROG8JAR=/path/to/prog8c-x.y.z-all.jar   (remembered in P8JARPATH)"; echo; exit 1; \
	fi
	$(if $(filter command line environment,$(origin PROG8JAR)),@echo "$(PROG8JAR)" > P8JARPATH)

tramp:
	@if [ -f a.out ]; then echo "Removing -->  a.out"; rm -f a.out; fi
	@echo "Assembling trampoline.s"
	64tass tramp.s -o a.out
	@[ -f a.out ] || { echo "Error assembling Trampoline object !"; echo; exit 1; }
	@tail -c +3 a.out > tramp.o

# $(call PROG8,VIDKIT-B1)  -> VIDKIT-B1.bin   (stale .bin is removed first so a failed build can't pass)
define PROG8
	@rm -f $(1).bin
	java -jar "$(PROG8JAR)" -target cx16 $(1).p8
	@[ -f $(1).bin ] || { echo "prog8 did not produce $(1).bin"; exit 1; }
	@echo
endef

b1: ; $(call PROG8,VIDKIT-B1)
b2: ; $(call PROG8,VIDKIT-B2)
b3: ; $(call PROG8,VIDKIT-B3)

engines:
	$(MAKE) -C VIDKIT-ENGINE
	cp VIDKIT-ENGINE/VIDKIT.ENGINE ./
	$(MAKE) -C SPIVID-ENGINE
	cp SPIVID-ENGINE/SPIVID.ENGINE ./

library:
	@for f in VIDKIT-B1.bin VIDKIT-B2.bin VIDKIT-B3.bin VIDKIT.ENGINE SPIVID.ENGINE; do \
	  if [ -f $$f ]; then echo "FOUND: $$f"; else echo "MISSING: $$f"; echo; exit 1; fi; \
	done
	@echo; echo "CREATING:  VIDKIT-A000.BIN"; rm -f VIDKIT-A000.BIN VIDKIT-A000.tmp; total=0; \
	for spec in VIDKIT-B1.bin:8192 VIDKIT.ENGINE:2560 VIDKIT-B2.bin:5632 SPIVID.ENGINE:5120 VIDKIT-B3.bin:0; do \
	  f=$${spec%%:*}; slot=$${spec##*:}; sz=$$(wc -c < "$$f" | tr -d ' '); \
	  [ $$slot -eq 0 ] && slot=$$sz; \
	  if [ $$sz -gt $$slot ]; then \
	    echo "ERROR: $$f is $$sz bytes but its slot is $$slot (over by $$((sz-slot)))"; rm -f VIDKIT-A000.tmp; exit 1; fi; \
	  pad=$$((slot-sz)); cat "$$f" >> VIDKIT-A000.tmp; \
	  [ $$pad -gt 0 ] && head -c $$pad /dev/zero >> VIDKIT-A000.tmp; \
	  echo "COPYING: $$f,  Size: $$sz"; \
	  [ $$pad -gt 0 ] && echo "PAD BYTES: $$pad   TOTAL BYTES: $$slot"; \
	  total=$$((total+slot)); echo; \
	done; \
	mv VIDKIT-A000.tmp VIDKIT-A000.BIN; echo " VIDKIT-A000.BIN  SIZE: $$total"

compress:
	@echo; echo "COMPRESSING:  VIDKIT-A000.BIN -> VIDKIT.Z"; rm -f VIDKIT.Z
	lzsa -r -f2 VIDKIT-A000.BIN VIDKIT.Z
	@[ -f VIDKIT.Z ] || { echo "lzsa did not produce VIDKIT.Z"; exit 1; }
	@echo " VIDKIT.Z  SIZE: $$(wc -c < VIDKIT.Z | tr -d ' ')"

EX := EXAMPLE VIDKIT CODE
PLAYER := $(EX)/X16 MOVIE PLAYER ( prog8 )
MAKER := $(EX)/MOVIE MAKER PLAYER TEMPLATES ( prog8 )

# $(call PUT,file,dir)
define PUT
	cp "$(1)" "$(2)/"
endef

install:
	@echo; echo "COPYING to the example folders"
	$(call PUT,VIDKIT-A000.BIN,$(EX)/BASLOAD CODE)
	$(call PUT,VIDKIT-A000.BIN,$(PLAYER))
	$(call PUT,VIDKIT-A000.BIN,$(PLAYER)/ASSETS)
	$(call PUT,VIDKIT-A000.BIN,$(MAKER)/ASSETS)
	$(call PUT,VIDKIT.Z,$(MAKER))

clean:
	rm -f SPIVID-ENGINE/SPIVID.ENGINE SPIVID-ENGINE/src/main.o
	rm -f VIDKIT-ENGINE/VIDKIT.ENGINE VIDKIT-ENGINE/src/main.o
	rm -f a.out tramp.o VIDKIT-B1.bin VIDKIT-B2.bin VIDKIT-B3.bin \
	      VIDKIT.ENGINE SPIVID.ENGINE BUILDVIDKIT.license.txt VIDKIT-A000.tmp
	rm -f *.asm *.vice-mon-list
