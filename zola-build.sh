#!/bin/bash
set -e -o pipefail

BASE_DIR=$(realpath $(dirname "$0"))
bash $BASE_DIR/zola-install.sh

mkdir -p $BASE_DIR/dist
PREVIEW_URL=${CF_PAGES_URL-$DEPLOY_URL}
HOMEPAGE_URL=${PREVIEW_URL-https://henrikgerdes.me}

echo "ENVs"

# Check if the variable is unset or empty
if [ -z "$HOMEPAGE_URL" ]; then
    HOMEPAGE_URL=https://henrikgerdes.me
else
    HOMEPAGE_URL=$PREVIEW_URL
fi
echo "Using url: ${HOMEPAGE_URL}"
zola --root $BASE_DIR build --base-url $HOMEPAGE_URL

cp -av $BASE_DIR/public/* $BASE_DIR/dist

echo "Build done!"
