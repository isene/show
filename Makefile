PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

show: show.asm
	nasm -f elf64 show.asm -o show.o
	ld show.o -o show
	rm -f show.o

install: show
	install -Dm755 show $(DESTDIR)$(BINDIR)/show
	@echo "Installed show to $(BINDIR)/show"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/show

clean:
	rm -f show show.o

.PHONY: install uninstall clean
