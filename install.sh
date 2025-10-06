#!/bin/sh
# Installation script for Topdesk toolkit
set -eu

# Default installation prefix
PREFIX=${PREFIX:-$HOME/.local}
DESTDIR=${DESTDIR:-}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect if output is a terminal
if [ -t 1 ]; then
  COLOR=${COLOR:-auto}
else
  COLOR=${COLOR:-never}
fi

# Setup colors based on COLOR env var
case "$COLOR" in
  never|no|false)
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
    ;;
  always|yes|true|auto)
    : # Keep colors as defined
    ;;
esac

# Helper functions
info() { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*" >&2; }
err() { printf "${RED}✗${NC} %s\n" "$*" >&2; }
die() { err "$*"; exit 1; }

# Check for required dependencies
check_dependencies() {
  info "Checking dependencies..."
  _deps_ok=1

  # Required
  if command -v curl >/dev/null 2>&1; then
    ok "curl found"
  else
    err "curl is required but not found"
    _deps_ok=0
  fi

  # Optional but recommended
  if command -v jq >/dev/null 2>&1; then
    ok "jq found (enables JSON formatting)"
  else
    warn "jq not found (optional, but recommended for JSON output)"
  fi

  if [ $_deps_ok -eq 0 ]; then
    die "Missing required dependencies. Please install them first."
  fi
}

# Show usage
usage() {
  cat <<EOF
Topdesk Toolkit Installation Script

Usage: $0 [options]

Options:
  -h, --help         Show this help
  -p, --prefix PATH  Installation prefix (default: $PREFIX)
  -u, --uninstall    Uninstall the toolkit
  -l, --link         Create symlink instead of copying (for development)
  -n, --no-path      Don't show PATH setup instructions

Examples:
  # Install to default location (~/.local)
  $0

  # Install to custom location
  $0 --prefix /opt/topdesk

  # Install system-wide
  sudo $0 --prefix /usr/local

  # Development install (symlink)
  $0 --link

  # Uninstall
  $0 --uninstall

The toolkit will be installed to:
  Binaries:  PREFIX/bin
  Libraries: PREFIX/share/topdesk-toolkit/lib
  Tools:     PREFIX/share/topdesk-toolkit/tools
  Examples:  PREFIX/share/topdesk-toolkit/share
EOF
}

# Install the toolkit
install_toolkit() {
  _install_mode=${1:-copy}
  _source_dir=$(cd "$(dirname "$0")" && pwd)

  info "Installing Topdesk toolkit..."
  info "Source: $_source_dir"
  info "Destination: $DESTDIR$PREFIX"
  info "Mode: $_install_mode"

  # Create directories
  for _dir in bin share/topdesk-toolkit/lib share/topdesk-toolkit/tools share/topdesk-toolkit/share; do
    _full_dir="$DESTDIR$PREFIX/$_dir"
    if [ ! -d "$_full_dir" ]; then
      info "Creating directory: $_full_dir"
      mkdir -p "$_full_dir" || die "Failed to create directory: $_full_dir"
    fi
  done

  # Install based on mode
  if [ "$_install_mode" = "link" ]; then
    # Development mode: create symlinks
    info "Creating symlinks (development mode)..."

    # Link entire directories
    for _component in lib tools share; do
      _src="$_source_dir/$_component"
      _dst="$DESTDIR$PREFIX/share/topdesk-toolkit/$_component"
      if [ -e "$_dst" ] || [ -L "$_dst" ]; then
        rm -rf "$_dst" || die "Failed to remove existing: $_dst"
      fi
      ln -sf "$_src" "$_dst" || die "Failed to link $_component"
      ok "Linked $_component"
    done

    # Link main binary
    _bin_src="$_source_dir/bin/topdesk"
    _bin_dst="$DESTDIR$PREFIX/bin/topdesk"
    if [ -e "$_bin_dst" ] || [ -L "$_bin_dst" ]; then
      rm -f "$_bin_dst" || die "Failed to remove existing binary"
    fi
    ln -sf "$_bin_src" "$_bin_dst" || die "Failed to link binary"
    ok "Linked main binary"
  else
    # Production mode: copy files
    info "Copying files..."

    # Copy libraries
    cp -r "$_source_dir/lib"/* "$DESTDIR$PREFIX/share/topdesk-toolkit/lib/" || die "Failed to copy libraries"
    ok "Copied libraries"

    # Copy tools
    cp -r "$_source_dir/tools"/* "$DESTDIR$PREFIX/share/topdesk-toolkit/tools/" || die "Failed to copy tools"
    ok "Copied tools"

    # Copy share files
    if [ -d "$_source_dir/share" ]; then
      cp -r "$_source_dir/share"/* "$DESTDIR$PREFIX/share/topdesk-toolkit/share/" 2>/dev/null || true
      ok "Copied share files"
    fi

    # Install main binary (creating wrapper)
    _bin_dst="$DESTDIR$PREFIX/bin/topdesk"
    cat > "$_bin_dst" <<EOF
#!/bin/sh
exec "$PREFIX/share/topdesk-toolkit/bin/topdesk" "\$@"
EOF
    chmod +x "$_bin_dst" || die "Failed to set executable permission"
    ok "Installed main binary"

    # Copy actual dispatcher
    cp "$_source_dir/bin/topdesk" "$DESTDIR$PREFIX/share/topdesk-toolkit/bin/" || die "Failed to copy dispatcher"
  fi

  # Set executable permissions on tools
  chmod +x "$DESTDIR$PREFIX/share/topdesk-toolkit/tools"/* 2>/dev/null || true

  ok "Installation complete!"
}

# Uninstall the toolkit
uninstall_toolkit() {
  info "Uninstalling Topdesk toolkit from $DESTDIR$PREFIX..."

  # Remove binary
  if [ -f "$DESTDIR$PREFIX/bin/topdesk" ] || [ -L "$DESTDIR$PREFIX/bin/topdesk" ]; then
    rm -f "$DESTDIR$PREFIX/bin/topdesk"
    ok "Removed binary"
  fi

  # Remove share directory
  if [ -d "$DESTDIR$PREFIX/share/topdesk-toolkit" ]; then
    rm -rf "$DESTDIR$PREFIX/share/topdesk-toolkit"
    ok "Removed toolkit files"
  fi

  # Note about config (don't remove user config)
  if [ -f "$HOME/.config/topdesk/config" ]; then
    info "Keeping user configuration at ~/.config/topdesk/config"
    info "Remove manually if no longer needed"
  fi

  ok "Uninstallation complete!"
}

# Show PATH setup instructions
show_path_setup() {
  _bin_dir="$PREFIX/bin"

  # Check if already in PATH
  case ":$PATH:" in
    *:"$_bin_dir":*)
      ok "$_bin_dir is already in your PATH"
      return
      ;;
  esac

  info "Add the following to your shell configuration file:"
  printf '\n'

  # Detect shell
  _shell=${SHELL##*/}
  case "$_shell" in
    bash)
      _rc="$HOME/.bashrc"
      ;;
    zsh)
      _rc="$HOME/.zshrc"
      ;;
    ksh)
      _rc="$HOME/.kshrc"
      ;;
    *)
      _rc="$HOME/.profile"
      ;;
  esac

  cat <<EOF
  # Topdesk toolkit
  export PATH="$_bin_dir:\$PATH"

Add to: $_rc

Or run this command:
  echo 'export PATH="$_bin_dir:\$PATH"' >> $_rc

Then reload your shell:
  source $_rc
EOF
}

# Parse arguments
MODE="install"
INSTALL_TYPE="copy"
SHOW_PATH=1

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -p|--prefix)
      shift
      PREFIX=${1:-}
      [ -n "$PREFIX" ] || die "PREFIX cannot be empty"
      ;;
    -u|--uninstall)
      MODE="uninstall"
      ;;
    -l|--link)
      INSTALL_TYPE="link"
      ;;
    -n|--no-path)
      SHOW_PATH=0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

# Main execution
case "$MODE" in
  install)
    check_dependencies
    install_toolkit "$INSTALL_TYPE"
    if [ $SHOW_PATH -eq 1 ]; then
      printf '\n'
      show_path_setup
    fi
    printf '\n'
    ok "Topdesk toolkit installed successfully!"
    info "Run 'topdesk help' to get started"
    info "Run 'topdesk config init' to create a configuration file"
    ;;
  uninstall)
    uninstall_toolkit
    ;;
esac