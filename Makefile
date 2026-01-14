NAME = swapos
VERSION = 2.1.0

# Standard variables for packaging
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/$(NAME)
SHAREDIR ?= $(PREFIX)/share/$(NAME)
DOCDIR ?= $(PREFIX)/share/doc/$(NAME)

.PHONY: install uninstall

install:
	@echo "Installing $(NAME)..."
	
	# Create directories
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(SHAREDIR)
	install -d $(DESTDIR)$(DOCDIR)
	
	# Install Executable
	install -m 755 src/swapos $(DESTDIR)$(BINDIR)/$(NAME)
	
	# Install Libraries
	install -m 644 src/lib/core.sh $(DESTDIR)$(LIBDIR)/core.sh
	install -m 644 src/lib/safety.sh $(DESTDIR)$(LIBDIR)/safety.sh
	
	# Install Default Config
	install -m 644 src/config.default $(DESTDIR)$(SHAREDIR)/config.default
	
	# Install Docs/License
	install -m 644 README.md $(DESTDIR)$(DOCDIR)/README.md
	install -m 644 LICENSE $(DESTDIR)$(DOCDIR)/LICENSE

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(NAME)
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -rf $(DESTDIR)$(SHAREDIR)
	rm -rf $(DESTDIR)$(DOCDIR)
