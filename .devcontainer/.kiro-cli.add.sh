#!/bin/bash

set -e

# Kiro CLI Installation Script
# This script installs Kiro CLI while avoiding conflicts with existing 'install' commands

echo "🚀 Installing Kiro CLI..."

# Create a temporary GNU-compatible install script to avoid conflicts
cat << 'EOF' > /tmp/install
#!/bin/sh
# GNU install compatible script for sh
MODE=""
if [ "$1" = "-m" ]; then
  MODE="$2"
  shift 2
fi
# Assume single source file
SOURCE="$1"
DEST="$2"
mkdir -p "$(dirname "$DEST")"
cp "$SOURCE" "$DEST"
[ -n "$MODE" ] && chmod "$MODE" "$DEST"
exit 0
EOF

chmod +x /tmp/install

# Temporarily prepend /tmp to PATH and run the installer
echo "📦 Downloading and installing Kiro CLI..."
PATH="/tmp:$PATH"
export PATH
curl -fsSL https://cli.kiro.dev/install | bash

# Cleanup
rm -f /tmp/install

echo "✅ Kiro CLI installation complete!"
echo "🎉 You can now use 'kiro-cli' command."
echo ""
echo "Next steps:"
echo "1. Ensure ~/.local/bin is in your PATH"
echo "2. Run 'kiro-cli --help' to get started"