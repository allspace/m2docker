#!/bin/bash
export BUILD_ROOT=$1
export IMG_BASE="$BUILD_ROOT/base"

if [ ! -d "$BUILD_ROOT" -o "$BUILD_ROOT" = "/" ]; then
    echo "Invalid BUILD_ROOT directory.";
    exit 1;
fi

#clean build folder
mkdir -p "$BUILD_ROOT/.rpms";
rm -f $BUILD_ROOT/.rpms/*;
mkdir -p "$IMG_BASE";
rm -rf $IMG_BASE/*

#functions
init_envs()
{
    M2D_APP_ROOT=$(realpath "$0");
	M2D_APP_ROOT=$(dirname "$M2D_APP_ROOT");
	export M2D_APP_ROOT;
	
    export M2D_LNX_ARCH=$(uname -i);
    if [ "$M2D_LNX_ARCH" = "x86_64" ]; then
        export M2D_LIB_DIR="lib64";
    else
        export M2D_LIB_DIR="lib";
    fi

    if [ -e /etc/redhat-release ]; then
        export M2D_LNX_DIST="redhat";
        if [ -h "/$M2D_LIB_DIR" ]; then
            export M2D_LIB_ROOT="/usr/$M2D_LIB_DIR";
        else
            export M2D_LIB_ROOT="/$M2D_LIB_DIR";
        fi
    fi
    export M2D_PKG_BLACKLIST="$M2D_APP_ROOT/blacklist/$M2D_LNX_DIST.lst";
}


###############################################################################
#main entry
###############################################################################
init_envs
case "$M2D_LNX_DIST" in
    redhat)
	suse)
		$M2D_APP_ROOT/scripts/copy_rpm.sh
		;;
	ubuntu)
	debian)
	    echo "[E001]Platform is not supported.";
		;;
esac

CUR=$(pwd);

cd $IMG_BASE;

rm -f ../base.tar
tar -cf ../base.tar .

cd $CUR;

