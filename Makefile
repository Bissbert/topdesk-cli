PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
SHAREDIR := $(PREFIX)/share
APPDIR := $(SHAREDIR)/topdesk-toolkit

USER_BASE := $(HOME)/.local
USER_BINDIR := $(USER_BASE)/bin
USER_APPDIR := $(USER_BASE)/share/topdesk-toolkit

.PHONY: all help install install-user install-dev uninstall uninstall-user clean gen-completions install-completions uninstall-completions check doctor test fmt fmt-check

# Default target: install for current user
all: install-user

help:
	@echo "Topdesk Toolkit - Installation Options:"
	@echo ""
	@echo "Default:"
	@echo "  make                  Install for current user to ~/.local (same as install-user)"
	@echo ""
	@echo "Installation targets:"
	@echo "  make install-user     Install for current user to ~/.local (DEFAULT)"
	@echo "  make install          Install system-wide to $(PREFIX)"
	@echo "  make install-dev      Development install with symlinks to ~/.local"
	@echo ""
	@echo "Other targets:"
	@echo "  make uninstall-user   Remove user installation"
	@echo "  make uninstall        Remove system-wide installation"
	@echo "  make test             Run test suite"
	@echo "  make check            Run shellcheck and format check"
	@echo "  make clean            Remove generated files"
	@echo "  make help             Show this help message"

install:
	@echo ">> Installing topdesk toolkit to $(APPDIR) and wrapper in $(BINDIR)"
	mkdir -p $(APPDIR)
	# copy suite files (preserve layout)
	install -m 0644 VERSION README.md $(APPDIR)/ 2>/dev/null || true
	mkdir -p $(APPDIR)/bin $(APPDIR)/lib $(APPDIR)/tools $(APPDIR)/share
	install -m 0755 bin/topdesk $(APPDIR)/bin/
	install -m 0644 lib/*.sh $(APPDIR)/lib/
	install -m 0755 tools/* $(APPDIR)/tools/
	# install share directory contents
	if [ -d share ]; then \
		cp -r share/* $(APPDIR)/share/ 2>/dev/null || true; \
	fi

	# wrapper in BINDIR to exec the installed dispatcher
	mkdir -p $(BINDIR)
	printf '%s\n' '#!/bin/sh' "exec \"$(APPDIR)/bin/topdesk\" \"\$$@\"" > $(BINDIR)/topdesk
	chmod 0755 $(BINDIR)/topdesk
	@echo ">> Done. Run: topdesk --version"

install-user:
	@echo ">> Installing topdesk toolkit to $(USER_APPDIR) and wrapper in $(USER_BINDIR)"
	mkdir -p $(USER_APPDIR)
	install -m 0644 VERSION README.md $(USER_APPDIR)/ 2>/dev/null || true
	mkdir -p $(USER_APPDIR)/bin $(USER_APPDIR)/lib $(USER_APPDIR)/tools $(USER_APPDIR)/share
	install -m 0755 bin/topdesk $(USER_APPDIR)/bin/
	install -m 0644 lib/*.sh $(USER_APPDIR)/lib/
	install -m 0755 tools/* $(USER_APPDIR)/tools/
	# install share directory contents
	if [ -d share ]; then \
		cp -r share/* $(USER_APPDIR)/share/ 2>/dev/null || true; \
	fi
	mkdir -p $(USER_BINDIR)
	printf '%s\n' '#!/bin/sh' "exec \"$(USER_APPDIR)/bin/topdesk\" \"\$$@\"" > $(USER_BINDIR)/topdesk
	chmod 0755 $(USER_BINDIR)/topdesk
	@echo ">> Ensuring user bin is on PATH (add to ~/.profile, ~/.bashrc, ~/.zshrc if needed)"
	@touch $(HOME)/.profile $(HOME)/.bashrc $(HOME)/.zshrc
	@grep -q 'topdesk-toolkit: add user bin to PATH' $(HOME)/.profile || { \
	  printf '%s\n' '# topdesk-toolkit: add user bin to PATH' \
	                 'case ":$$PATH:" in' \
	                 '  *":$$HOME/.local/bin:"*) ;;' \
	                 '  *) export PATH="$$HOME/.local/bin:$$PATH" ;;' \
	                 'esac' >> $(HOME)/.profile ; }
	@grep -q 'topdesk-toolkit: add user bin to PATH' $(HOME)/.bashrc || { \
	  printf '%s\n' '# topdesk-toolkit: add user bin to PATH' \
	                 'case ":$$PATH:" in' \
	                 '  *":$$HOME/.local/bin:"*) ;;' \
	                 '  *) export PATH="$$HOME/.local/bin:$$PATH" ;;' \
	                 'esac' >> $(HOME)/.bashrc ; }
	@grep -q 'topdesk-toolkit: add user bin to PATH' $(HOME)/.zshrc || { \
	  printf '%s\n' '# topdesk-toolkit: add user bin to PATH' \
	                 'case ":$$PATH:" in' \
	                 '  *":$$HOME/.local/bin:"*) ;;' \
	                 '  *) export PATH="$$HOME/.local/bin:$$PATH" ;;' \
	                 'esac' >> $(HOME)/.zshrc ; }
	@echo ">> Done. Open a new terminal or run: exec $$SHELL -l"

install-dev:
	@echo ">> Installing development symlinks to $(USER_APPDIR)"
	@echo ">> This links directly to the source directory for development"
	# Create base directories
	mkdir -p $(USER_APPDIR) $(USER_BINDIR)
	# Remove any existing installation
	rm -rf $(USER_APPDIR)/lib $(USER_APPDIR)/tools $(USER_APPDIR)/share $(USER_APPDIR)/bin
	# Create symlinks to source directories
	ln -sf $(PWD)/lib $(USER_APPDIR)/lib
	ln -sf $(PWD)/tools $(USER_APPDIR)/tools
	ln -sf $(PWD)/share $(USER_APPDIR)/share
	ln -sf $(PWD)/bin $(USER_APPDIR)/bin
	# Link VERSION and README if they exist
	[ -f VERSION ] && ln -sf $(PWD)/VERSION $(USER_APPDIR)/VERSION || true
	[ -f README.md ] && ln -sf $(PWD)/README.md $(USER_APPDIR)/README.md || true
	# Create wrapper in USER_BINDIR
	printf '%s\n' '#!/bin/sh' "exec \"$(USER_APPDIR)/bin/topdesk\" \"\$$@\"" > $(USER_BINDIR)/topdesk
	chmod 0755 $(USER_BINDIR)/topdesk
	@echo ">> Development installation complete"
	@echo ">> Changes to source files will be immediately reflected"
	@echo ">> Ensure ~/.local/bin is in your PATH"

uninstall:
	@echo ">> Removing system install from $(PREFIX)"
	rm -f $(BINDIR)/topdesk || true
	rm -rf $(APPDIR) || true
	@echo ">> System uninstall complete"

uninstall-user:
	@echo ">> Removing user install from $(USER_BASE)"
	rm -f $(USER_BINDIR)/topdesk || true
	rm -rf $(USER_APPDIR) || true
	@echo ">> User uninstall complete"
	@echo ">> Note: User config at ~/.config/topdesk/ was preserved"

clean:
	@echo ">> Cleaning generated files"
	rm -rf completions/
	rm -f VERSION 2>/dev/null || true
	@echo ">> Clean complete"

gen-completions:
	@echo ">> Generating shell completions"
	mkdir -p completions
	PATH="$(PWD)/bin:$$PATH" topdesk completion bash > completions/topdesk.bash

install-completions: gen-completions
	@echo ">> Installing Bash completion"
	@if [ -d /usr/share/bash-completion/completions ] && [ -w /usr/share/bash-completion/completions ]; then \
	  install -m 0644 completions/topdesk.bash /usr/share/bash-completion/completions/topdesk ; \
	  echo "Installed to /usr/share/bash-completion/completions/topdesk" ; \
	elif [ -d /etc/bash_completion.d ] && [ -w /etc/bash_completion.d ]; then \
	  install -m 0644 completions/topdesk.bash /etc/bash_completion.d/topdesk ; \
	  echo "Installed to /etc/bash_completion.d/topdesk" ; \
	else \
	  mkdir -p $(HOME)/.local/share/bash-completion/completions ; \
	  install -m 0644 completions/topdesk.bash $(HOME)/.local/share/bash-completion/completions/topdesk ; \
	  echo "Installed to $(HOME)/.local/share/bash-completion/completions/topdesk" ; \
	fi

	@echo ">> Ensuring bash-completion is loaded for new shells"
	@touch $(HOME)/.bashrc
	@grep -q 'topdesk-toolkit: enable bash-completion' $(HOME)/.bashrc || { \
	  printf '%s\n' '# topdesk-toolkit: enable bash-completion' \
	                 'case "$$-" in *i*)' \
	                 '  if [ -f /usr/share/bash-completion/bash_completion ]; then' \
	                 '    . /usr/share/bash-completion/bash_completion' \
	                 '  elif [ -f /etc/bash_completion ]; then' \
	                 '    . /etc/bash_completion' \
	                 '  fi' \
	                 ';; esac' >> $(HOME)/.bashrc ; }

	@echo ">> Reload your shell to activate completion: exec $$SHELL -l"
	@echo ">> Or run now: source /usr/share/bash-completion/bash_completion 2>/dev/null || source /etc/bash_completion; source $$HOME/.local/share/bash-completion/completions/topdesk"

uninstall-completions:
	@echo ">> Removing Bash completion"
	@rm -f /usr/share/bash-completion/completions/topdesk /etc/bash_completion.d/topdesk $(HOME)/.local/share/bash-completion/completions/topdesk || true

check:
	@echo ">> Running checks (shellcheck)"
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -e SC1007 -e SC2015 -e SC1090 -e SC1091 -x bin/topdesk lib/*.sh tools/* || exit 1; \
	else \
	  echo "shellcheck not found; skipping static analysis"; \
	fi
	@$(MAKE) --no-print-directory fmt-check

test:
	@echo ">> Running test suite"
	@bash tests/run.sh

fmt:
	@echo ">> Formatting shell sources with shfmt"
	@if command -v shfmt >/dev/null 2>&1; then \
	  shfmt -w bin/topdesk lib/*.sh tools/* tests/*.sh tests/bin/*; \
	else \
	  echo "shfmt not found; skipping fmt (install shfmt to enable)"; \
	fi

fmt-check:
	@if command -v shfmt >/dev/null 2>&1; then \
	  out=$$(shfmt -d bin/topdesk lib/*.sh tools/* tests/*.sh tests/bin/* || true); \
	  if [ -n "$$out" ]; then \
	    printf '%s\n' "$${out}"; \
	    exit 1; \
	  fi; \
	else \
	  echo "shfmt not found; skipping fmt-check"; \
	fi
