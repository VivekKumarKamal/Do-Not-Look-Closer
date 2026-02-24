#!/bin/bash
# Downloads and extracts Sparkle framework (needed for building)
# Run this once after cloning the repo
set -e

SPARKLE_VERSION="2.6.4"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

if [ -d "Frameworks/Sparkle.framework" ]; then
    echo "✅ Sparkle.framework already exists"
    exit 0
fi

echo "📥 Downloading Sparkle ${SPARKLE_VERSION}..."
curl -L -o /tmp/sparkle.tar.xz "${SPARKLE_URL}"

echo "📦 Extracting..."
mkdir -p Frameworks
cd Frameworks
tar xf /tmp/sparkle.tar.xz
rm /tmp/sparkle.tar.xz

echo "✅ Sparkle.framework installed in Frameworks/"
