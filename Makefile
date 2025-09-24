PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
SHAREDIR := $(PREFIX)/share
APPDIR := $(SHAREDIR)/topdesk-toolkit

USER_BASE := $(HOME)/.local
USER_BINDIR := $(USER_BASE)/bin
USER_APPDIR := $(USER_BASE)/share/topdesk-toolkit

.PHONY: all install install-user uninstall gen-completions install-completions uninstall-completions check doctor test fmt fmt-check

all:
	@echo "Run 'make install' (system) or 'make install-user' (per-user)."
	@echo "Other useful targets: gen-completions, install-completions, uninstall-completions, check"

install:
	@echo ">> Installing topdesk toolkit to $(APPDIR) and wrapper in $(BINDIR)"
	mkdir -p $(APPDIR)
	# copy suite files (preserve layout)
	install -m 0644 VERSION README.md TODO.md $(APPDIR)/
	mkdir -p $(APPDIR)/bin $(APPDIR)/lib $(APPDIR)/tools $(APPDIR)/share
	install -m 0755 bin/topdesk $(APPDIR)/bin/
	install -m 0755 lib/*.sh $(APPDIR)/lib/
	install -m 0755 tools/* $(APPDIR)/tools/
	# optional share dir if we add templates later
	# install -m 0755 -d $(APPDIR)/share

	# wrapper in BINDIR to exec the installed dispatcher
	mkdir -p $(BINDIR)
	printf '%s\n' '#!/bin/sh' 'exec "$(APPDIR)/bin/topdesk" "$$@"' > $(BINDIR)/topdesk
	chmod 0755 $(BINDIR)/topdesk
	@echo ">> Done. Run: topdesk --version"

install-user:
	@echo ">> Installing topdesk toolkit to $(USER_APPDIR) and wrapper in $(USER_BINDIR)"
	mkdir -p $(USER_APPDIR)
	install -m 0644 VERSION README.md TODO.md $(USER_APPDIR)/
	mkdir -p $(USER_APPDIR)/bin $(USER_APPDIR)/lib $(USER_APPDIR)/tools $(USER_APPDIR)/share
	install -m 0755 bin/topdesk $(USER_APPDIR)/bin/
	install -m 0755 lib/*.sh $(USER_APPDIR)/lib/
	install -m 0755 tools/* $(USER_APPDIR)/tools/
	mkdir -p $(USER_BINDIR)
	printf '%s\n' '#!/bin/sh' 'exec "$(USER_APPDIR)/bin/topdesk" "$$@"' > $(USER_BINDIR)/topdesk
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

uninstall:
	@echo ">> Removing system install"
	rm -f $(BINDIR)/topdesk || true
	rm -rf $(APPDIR) || true

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
