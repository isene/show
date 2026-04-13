PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1

show: show.asm
	nasm -f elf64 show.asm -o show.o
	ld show.o -o show
	rm -f show.o

install: show
	install -Dm755 show $(DESTDIR)$(BINDIR)/show
	install -Dm644 show.1 $(DESTDIR)$(MANDIR)/show.1
	@echo "Installed show to $(BINDIR)/show"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/show
	rm -f $(DESTDIR)$(MANDIR)/show.1

clean:
	rm -f show show.o

.PHONY: install uninstall clean
