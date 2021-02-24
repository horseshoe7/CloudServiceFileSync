#!/bin/sh

if which swiftgen >/dev/null; then
echo "Running SwiftGen to update Localization L10n.swift and create Asset constants."
cd "$SRCROOT"
cd "$PRODUCT_MODULE_NAME/Pipelines"

# show current dir
echo $PWD
#swiftgen.yml is in SRCROOT folder...
# do it!
swiftgen config run --config swiftgen-localization.yml
#swiftgen config run --config swiftgen-assets.yml
else
if [ "${CONFIGURATION}" = "Debug" ]; then
echo "warning: SwiftGen not installed, download it from https://github.com/SwiftGen/SwiftGen"
fi
fi
