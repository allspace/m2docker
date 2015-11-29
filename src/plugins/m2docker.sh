#!/bin/bash
export BUILD_ROOT=$1
export IMG_BASE="$BUILD_ROOT/base"

if [ ! -d "$BUILD_ROOT" -o "$BUILD_ROOT" = "/" ]; then
    echo "Invalid BUILD_ROOT directory.";
    exit 1;
fi

mkdir -p "$BUILD_ROOT/.rpms";
rm -f $BUILD_ROOT/.rpms/*;
mkdir -p "$IMG_BASE";
rm -rf $IMG_BASE/*

./copy_rpm.sh

CUR=$(pwd);

cd $IMG_BASE;

rm -f ../base.tar
tar -cf ../base.tar .

cd $CUR;

