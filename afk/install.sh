#!/bin/bash
# Installation script for AFK application
# Copies afk.sh to ~/.local/bin/afk and makes it executable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AFK_SCRIPT="${SCRIPT_DIR}/afk.sh"
AFK_DESKTOP="${SCRIPT_DIR}/afk.desktop"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/afk"
APPLICATIONS_DIR="${HOME}/.local/share/applications"
DESKTOP_ENTRY_PATH="${APPLICATIONS_DIR}/afk.desktop"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "AFK Application Installer"
echo "========================"
echo ""

# Check if afk.sh exists
if [[ ! -f "$AFK_SCRIPT" ]]; then
    echo -e "${RED}ERROR:${NC} afk.sh not found at $AFK_SCRIPT"
    exit 1
fi

# Check if afk.desktop exists
if [[ ! -f "$AFK_DESKTOP" ]]; then
    echo -e "${RED}ERROR:${NC} afk.desktop not found at $AFK_DESKTOP"
    exit 1
fi

# Create install directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Creating directory:${NC} $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if already installed
if [[ -f "$INSTALL_PATH" ]]; then
    echo -e "${YELLOW}WARNING:${NC} afk is already installed at $INSTALL_PATH"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Copy script
echo -e "${GREEN}Installing afk to:${NC} $INSTALL_PATH"
cp "$AFK_SCRIPT" "$INSTALL_PATH"

# Make executable
chmod +x "$INSTALL_PATH"

# Install desktop entry
echo ""
echo -e "${GREEN}Installing desktop entry...${NC}"

# Create applications directory if it doesn't exist
if [[ ! -d "$APPLICATIONS_DIR" ]]; then
    echo -e "${YELLOW}Creating directory:${NC} $APPLICATIONS_DIR"
    mkdir -p "$APPLICATIONS_DIR"
fi

# Check if desktop entry already exists
if [[ -f "$DESKTOP_ENTRY_PATH" ]]; then
    echo -e "${YELLOW}Desktop entry already exists at:${NC} $DESKTOP_ENTRY_PATH"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping desktop entry installation."
    else
        # Create desktop entry with full path to the installed script
        sed "s|^Exec=afk|Exec=${INSTALL_PATH}|" "$AFK_DESKTOP" > "$DESKTOP_ENTRY_PATH"
        echo -e "${GREEN}Desktop entry installed to:${NC} $DESKTOP_ENTRY_PATH"
        
        # Update desktop database
        if command -v update-desktop-database &> /dev/null; then
            echo "Updating desktop database..."
            update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
        fi
    fi
else
    # Create desktop entry with full path to the installed script
    sed "s|^Exec=afk|Exec=${INSTALL_PATH}|" "$AFK_DESKTOP" > "$DESKTOP_ENTRY_PATH"
    echo -e "${GREEN}Desktop entry installed to:${NC} $DESKTOP_ENTRY_PATH"
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        echo "Updating desktop database..."
        update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
    fi
fi

# Verify dependencies
echo ""
echo "Verifying dependencies..."
echo ""

MISSING_DEPS=0

check_dependency() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name found"
    else
        echo -e "${RED}✗${NC} $name not found"
        MISSING_DEPS=1
    fi
}

check_dependency "hyprmon" "hyprmon"
check_dependency "tmux" "tmux"
check_dependency "sleep-guard" "sleep-guard"
check_dependency "pkill" "pkill"
check_dependency "pgrep" "pgrep"

echo ""

if [[ $MISSING_DEPS -eq 1 ]]; then
    echo -e "${YELLOW}WARNING:${NC} Some dependencies are missing. The script may not work correctly."
    echo "Please install missing dependencies before using afk."
else
    echo -e "${GREEN}All dependencies found!${NC}"
fi

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}NOTE:${NC} $INSTALL_DIR is not in your PATH."
    echo "Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Or run afk with full path: $INSTALL_PATH"
else
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo "You can now run 'afk' from anywhere."
fi

echo ""
echo "Usage:"
echo "  Command line: afk"
echo "  Application launcher: Search for 'AFK Toggle' in rofi or your application menu"
