#!/bin/bash
set -e

# Suna macOS Installer Build Script
# Creates a .pkg installer for VST3 and AU plugins

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
INSTALLER_DIR="$PROJECT_ROOT/installer"
VERSION="${SUNA_VERSION:-}"
if [ -n "$VERSION" ]; then
    VERSION="${VERSION#v}"
fi
if [ -z "$VERSION" ] && [ -n "${GITHUB_REF_NAME:-}" ]; then
    VERSION="${GITHUB_REF_NAME#v}"
fi
if [ -z "$VERSION" ]; then
    VERSION=$(grep -E "project\(Suna VERSION" "$PROJECT_ROOT/CMakeLists.txt" | sed -E 's/.*VERSION ([0-9.]+).*/\1/')
fi
if [ -z "$VERSION" ]; then
    VERSION="0.1.0"
fi
IDENTIFIER="com.sunaaudio.suna"

# Plugin paths
VST3_PATH="$BUILD_DIR/plugin/Suna_artefacts/Release/VST3/Suna.vst3"
AU_PATH="$BUILD_DIR/plugin/Suna_artefacts/Release/AU/Suna.component"

# Install destinations (system-wide)
VST3_INSTALL_DIR="/Library/Audio/Plug-Ins/VST3"
AU_INSTALL_DIR="/Library/Audio/Plug-Ins/Components"

echo "=== Suna macOS Installer Build ==="
echo "Version: $VERSION"
echo ""

# Clean previous installer artifacts
rm -rf "$INSTALLER_DIR"
mkdir -p "$INSTALLER_DIR/pkg" "$INSTALLER_DIR/root/vst3" "$INSTALLER_DIR/root/au"

# Check if plugins exist
if [ ! -d "$VST3_PATH" ]; then
    echo "Error: VST3 plugin not found at $VST3_PATH"
    echo "Run 'npm run release:vst' first to build the Release version."
    exit 1
fi

if [ ! -d "$AU_PATH" ]; then
    echo "Error: AU plugin not found at $AU_PATH"
    echo "Run 'npm run release:vst' first to build the Release version."
    exit 1
fi

echo "Found plugins:"
echo "  VST3: $VST3_PATH"
echo "  AU:   $AU_PATH"
echo ""

# Copy plugins to staging area
echo "Staging plugins..."
cp -R "$VST3_PATH" "$INSTALLER_DIR/root/vst3/"
cp -R "$AU_PATH" "$INSTALLER_DIR/root/au/"

# Build VST3 component package
echo "Building VST3 package..."
pkgbuild \
    --root "$INSTALLER_DIR/root/vst3" \
    --install-location "$VST3_INSTALL_DIR" \
    --identifier "${IDENTIFIER}.vst3" \
    --version "$VERSION" \
    "$INSTALLER_DIR/pkg/suna-vst3.pkg"

# Build AU component package
echo "Building AU package..."
pkgbuild \
    --root "$INSTALLER_DIR/root/au" \
    --install-location "$AU_INSTALL_DIR" \
    --identifier "${IDENTIFIER}.component" \
    --version "$VERSION" \
    "$INSTALLER_DIR/pkg/suna-au.pkg"

# Create distribution XML
cat > "$INSTALLER_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Suna</title>
    <organization>com.sunaaudio</organization>
    <welcome file="welcome.html"/>
    <license file="license.html"/>
    <conclusion file="conclusion.html"/>
    
    <options customize="allow" require-scripts="false" rootVolumeOnly="true"/>
    
    <choices-outline>
        <line choice="vst3"/>
        <line choice="au"/>
    </choices-outline>
    
    <choice id="vst3" title="VST3 Plugin" description="Install Suna VST3 to /Library/Audio/Plug-Ins/VST3/">
        <pkg-ref id="${IDENTIFIER}.vst3"/>
    </choice>
    
    <choice id="au" title="Audio Unit Plugin" description="Install Suna AU to /Library/Audio/Plug-Ins/Components/">
        <pkg-ref id="${IDENTIFIER}.component"/>
    </choice>
    
    <pkg-ref id="${IDENTIFIER}.vst3" version="$VERSION" onConclusion="none">suna-vst3.pkg</pkg-ref>
    <pkg-ref id="${IDENTIFIER}.component" version="$VERSION" onConclusion="none">suna-au.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create resources directory
mkdir -p "$INSTALLER_DIR/resources"

# Create welcome page
cat > "$INSTALLER_DIR/resources/welcome.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; }
        h1 { color: #333; }
        p { color: #666; line-height: 1.6; }
    </style>
</head>
<body>
    <h1>Suna v${VERSION}</h1>
    <p>A sampler plugin with MoonBit DSP compiled to WebAssembly.</p>
    <p><strong>Features:</strong></p>
    <ul>
        <li>8-slot sampler with XY blend control</li>
        <li>MoonBit DSP compiled to WebAssembly</li>
        <li>Modern Vue 3 UI</li>
    </ul>
    <p>This installer will install both VST3 and Audio Unit versions.</p>
</body>
</html>
EOF

# Create license page
cat > "$INSTALLER_DIR/resources/license.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; }
        pre { background: #f5f5f5; padding: 15px; overflow: auto; font-size: 12px; }
    </style>
</head>
<body>
    <h2>MIT License</h2>
    <pre>
Copyright (c) 2025 SunaAudio

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
    </pre>
</body>
</html>
EOF

# Create conclusion page
cat > "$INSTALLER_DIR/resources/conclusion.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; }
        h1 { color: #4CAF50; }
        p { color: #666; line-height: 1.6; }
        code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>Installation Complete!</h1>
    <p>Suna has been successfully installed.</p>
    <p><strong>Plugin locations:</strong></p>
    <ul>
        <li>VST3: <code>/Library/Audio/Plug-Ins/VST3/Suna.vst3</code></li>
        <li>AU: <code>/Library/Audio/Plug-Ins/Components/Suna.component</code></li>
    </ul>
    <p>Restart your DAW to load the plugin.</p>
</body>
</html>
EOF

# Build final product
echo "Building final installer..."
productbuild \
    --distribution "$INSTALLER_DIR/distribution.xml" \
    --resources "$INSTALLER_DIR/resources" \
    --package-path "$INSTALLER_DIR/pkg" \
    "$INSTALLER_DIR/Suna-${VERSION}-macOS.pkg"

echo ""
echo "=== Build Complete ==="
echo "Installer: $INSTALLER_DIR/Suna-${VERSION}-macOS.pkg"
echo ""
echo "To test installation:"
echo "  sudo installer -pkg \"$INSTALLER_DIR/Suna-${VERSION}-macOS.pkg\" -target /"
