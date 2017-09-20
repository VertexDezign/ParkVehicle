#!/bin/sh

ZIPNAME="FS17_parkVehicle.zip"
MOD_DIR="C:\Users\benjamin\Documents\My Games\FarmingSimulator2017\mods"

if [ -f $ZIPNAME ]; then
    echo "Remove old zip"
    rm $ZIPNAME
fi

echo "Create new zip"
"C:\Program Files\7-Zip\7z.exe" a -x!*.sh -x!.git -x!LICENSE -x!*.zip -x!*.iml -x!.idea -x!*.md -x!*.pdn -x!*.png -tzip $ZIPNAME *

echo "Copy to mods directory"
cp -f $ZIPNAME "$MOD_DIR"