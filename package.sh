#!/bin/bash
# Script de packaging pour publication
# Cree un zip ShareCraft-X.Y.Z.zip avec la bonne structure

VERSION=$(grep "## Version" ShareCraft.toc | sed 's/## Version: //')
ZIPNAME="ShareCraft-${VERSION}.zip"

echo "Packaging ShareCraft v${VERSION}..."

# Clean previous build
rm -f "$ZIPNAME"

# Create zip with ShareCraft/ folder structure
mkdir -p build/ShareCraft
cp ShareCraft.toc Data.lua Core.lua Scanner.lua Export.lua UI.lua build/ShareCraft/
cd build
zip -r "../$ZIPNAME" ShareCraft/
cd ..
rm -rf build

echo "Created $ZIPNAME"
echo ""
echo "Upload this file to:"
echo "  - CurseForge: https://www.curseforge.com/wow/addons"
echo "  - Wago:       https://addons.wago.io"
echo "  - WoWInterface: https://www.wowinterface.com"
