NAME = swapos

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/$(NAME)
CONFDIR ?= /etc/$(NAME)

.PHONY: install uninstall check

install:
	@echo "Installing $(NAME)..."
	
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(CONFDIR)
	
	install -m 755 src/swapos $(DESTDIR)$(BINDIR)/$(NAME)
	
	install -m 644 src/lib/core.sh $(DESTDIR)$(LIBDIR)/core.sh
	install -m 644 src/lib/safety.sh $(DESTDIR)$(LIBDIR)/safety.sh
	
	@if [ ! -f $(DESTDIR)$(CONFDIR)/config ]; then \
		echo "Installing default config to $(CONFDIR)/config"; \
		install -m 644 src/config.default $(DESTDIR)$(CONFDIR)/config; \
	else \
		echo "Config file exists. Skipping overwrite."; \
	fi

uninstall:
	@echo "Uninstalling $(NAME)..."
	rm -f $(DESTDIR)$(BINDIR)/$(NAME)
	rm -rf $(DESTDIR)$(LIBDIR)

# Syntax checks
check:
	bash -n src/swapos
	bash -n src/lib/core.sh
	bash -n src/lib/safety.sh
