#!/bin/bash

# Documentation for pkgbuild and productbuild: https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html

# preflight check
INDIR=$1
SOURCEDIR=$2
TARGET_DIR=$3
VERSION=$4


#MAC_SIGNING_CERT="Developer ID Application: Benjamin Thompson (4VUHZPUT62)"
#MAC_INSTALLING_CERT="Developer ID Installer: Benjamin Thompson (4VUHZPUT62)"
#MAC_SIGNING_1UPW="qwyh-jmdf-fqki-btgb"
#MAC_SIGNING_ID="benjaminrthompson.mail@gmail.com"
#MAC_SIGNING_TEAM="4VUHZPUT62"

TMPDIR="./installer-tmp"
mkdir -p $TMPDIR

echo "MAKE from $INDIR $SOURCEDIR into $TARGET_DIR with $VERSION"

VST3="playBackEQ.vst3"
AU="playBackEQ.component"

if [ "$VERSION" == "" ]; then
    echo "You must specify the version you are packaging!"
    echo "eg: ./make_installer.sh 1.0.6b4"
    exit 1
fi

OUTPUT_BASE_FILENAME="playBackEQ-macOS-$VERSION"

echo --- BUILDING playBackEQ_VST3.pkg from $VST3 ---

workdir=$TMPDIR/VST3
mkdir -p $workdir

cp -r ~/Library/Audio/Plug-Ins/VST3/$VST3 "$workdir"
ls -l "$workdir"

echo "Signing as a bundle"

#codesign --force -s "Developer ID Application: Your Name (2DO8NL92GO)" -v ~/Downloads/myApp.app --deep --strict --options=runtime --timestamp

codesign --force -s "$MAC_SIGNING_CERT" -o runtime --deep "$workdir/$VST3"
codesign -vvv "$workdir/$VST3"

pkgbuild --sign "$MAC_INSTALLING_CERT" --root "$workdir" --identifier "com.obscureSignals.playBackEQ.vst3.pkg" --version "$VERSION" --install-location "/Library/Audio/Plug-Ins/VST3" "$TMPDIR/playBackEQ_VST3.pkg" || exit 1
pkgutil --check-signature "$TMPDIR/playBackEQ_VST3.pkg"

rm -rf $workdir

echo --- BUILDING playBackEQ_AU.pkg from $AU ---

workdir=$TMPDIR/"AU"
mkdir -p "$workdir"

cp -r ~/Library/Audio/Plug-Ins/Components/$AU "$workdir"
ls -l "$workdir"

echo "Signing as a bundle"
codesign --force -s "$MAC_SIGNING_CERT" -o runtime --deep "$workdir/$AU"
codesign -vvv "$workdir/$AU"

pkgbuild --sign "$MAC_INSTALLING_CERT" --root "$workdir" --identifier "com.obscureSignals.playBackEQ.component.pkg" --version "$VERSION" --install-location "/Library/Audio/Plug-Ins/Components/" "$TMPDIR/playBackEQ_AU.pkg" || exit 1
pkgutil --check-signature "$TMPDIR/playBackEQ_AU.pkg"

rm -rf $workdir

# Build the resources pagkage
RSRCS=${SOURCEDIR}/packaging/factoryPresets
echo --- BUILDING factoryPresets pkg ---

# We have to install the factory presets in a temp location and then move it to the user location with the postinstall script.
pkgbuild --sign "$MAC_INSTALLING_CERT" --root "$RSRCS" --identifier "com.obscureSignals.playBackEQ.resources.pkg" --version "$VERSION" --scripts ${SOURCEDIR}/packaging/ResourcesPackageScript --install-location "/tmp/playBackEQ/factoryPresets/" ${TMPDIR}/factoryPresets.pkg

echo --- Sub Packages Created ---
ls -l "${TMPDIR}"

# create distribution.xml

VST3_PKG_REF='<pkg-ref id="com.obscureSignals.playBackEQ.vst3.pkg"/>'
VST3_CHOICE='<line choice="com.obscureSignals.playBackEQ.vst3.pkg"/>'
VST3_CHOICE_DEF="<choice id=\"com.obscureSignals.playBackEQ.vst3.pkg\" visible=\"true\" start_selected=\"true\" title=\"playBackEQ VST3\"><pkg-ref id=\"com.obscureSignals.playBackEQ.vst3.pkg\"/></choice><pkg-ref id=\"com.obscureSignals.playBackEQ.vst3.pkg\" version=\"${VERSION}\" onConclusion=\"none\">playBackEQ_VST3.pkg</pkg-ref>"

AU_PKG_REF='<pkg-ref id="com.obscureSignals.playBackEQ.component.pkg"/>'
AU_CHOICE='<line choice="com.obscureSignals.playBackEQ.component.pkg"/>'
AU_CHOICE_DEF="<choice id=\"com.obscureSignals.playBackEQ.component.pkg\" visible=\"true\" start_selected=\"true\" title=\"playBackEQ Audio Unit\"><pkg-ref id=\"com.obscureSignals.playBackEQ.component.pkg\"/></choice><pkg-ref id=\"com.obscureSignals.playBackEQ.component.pkg\" version=\"${VERSION}\" onConclusion=\"none\">playBackEQ_AU.pkg</pkg-ref>"

cat > $TMPDIR/distribution.xml << XMLEND
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>playBackEQ ${VERSION}</title>
    <license file="License.txt" />
    <readme file="Readme.rtf" />

    ${AU_PKG_REF}
    ${VST3_PKG_REF}

    <pkg-ref id="com.obscureSignals.playBackEQ.resources.pkg"/>
    <options require-scripts="false" customize="always" hostArchitectures="x86_64,arm64" rootVolumeOnly="true"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
        ${AU_CHOICE}
        ${VST3_CHOICE}

        <line choice="com.obscureSignals.playBackEQ.resources.pkg"/>
    </choices-outline>
    ${VST3_CHOICE_DEF}
    ${AU_CHOICE_DEF}

    <choice id="com.obscureSignals.playBackEQ.resources.pkg" visible="true" enabled="false" selected="true" title="Install Factory Presets">
        <pkg-ref id="com.obscureSignals.playBackEQ.resources.pkg"/>
    </choice>
    <pkg-ref id="com.obscureSignals.playBackEQ.resources.pkg" version="${VERSION}" onConclusion="none">factoryPresets.pkg</pkg-ref>
</installer-gui-script>
XMLEND

# build installation bundle

pushd ${TMPDIR} || exit
echo "Building SIGNED PKG"
productbuild --sign "$MAC_INSTALLING_CERT" --distribution "distribution.xml" --package-path "." --resources "${SOURCEDIR}"/packaging "$OUTPUT_BASE_FILENAME.pkg"

popd || exit

#Rez -append ${SOURCEDIR}/packaging/icns.rsrc -o "${TMPDIR}/${OUTPUT_BASE_FILENAME}.pkg"
SetFile -a C "${TMPDIR}/${OUTPUT_BASE_FILENAME}.pkg"
mkdir "${TMPDIR}/playBackEQ"
mv "${TMPDIR}/${OUTPUT_BASE_FILENAME}.pkg" "${TMPDIR}/playBackEQ"
# create a DMG if required

if [[ -f "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg" ]]; then
  rm "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg"
fi
hdiutil create /tmp/tmp.dmg -ov -volname "$OUTPUT_BASE_FILENAME" -fs HFS+ -srcfolder "${TMPDIR}/playBackEQ/"
hdiutil convert /tmp/tmp.dmg -format UDZO -o "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg"

codesign --force -s "$MAC_SIGNING_CERT" --timestamp "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg"
codesign -vvv "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg"
xcrun notarytool submit "${TARGET_DIR}/$OUTPUT_BASE_FILENAME.dmg" --apple-id ${MAC_SIGNING_ID} --team-id ${MAC_SIGNING_TEAM} --password ${MAC_SIGNING_1UPW} --wait
xcrun stapler staple "${TARGET_DIR}/${OUTPUT_BASE_FILENAME}.dmg"

rm -r $TMPDIR
