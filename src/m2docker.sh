#!/bin/bash
export M2D_APP_NAME=$1
export BUILD_ROOT=$2


#functions
print_usage()
{
	echo "Usage: %0 APP_NAME BUILD_ROOT";
}
init_envs()
{
	local rc="";
	
	export IMG_BASE="$BUILD_ROOT/base"
	
    M2D_APP_ROOT=$(readlink -f "$0");
    M2D_APP_ROOT=$(dirname "$M2D_APP_ROOT");
    export M2D_APP_ROOT;
	
    export M2D_LNX_ARCH=$(uname -i);
    if [ "$M2D_LNX_ARCH" = "x86_64" ]; then
        export M2D_LIB_DIR="lib64";
    else
        export M2D_LIB_DIR="lib";
    fi

    if [ -e /etc/redhat-release ]; then
        export M2D_LNX_TYPE="redhat";
        if [ -h "/$M2D_LIB_DIR" ]; then
            export M2D_LIB_ROOT="/usr/$M2D_LIB_DIR";
        else
            export M2D_LIB_ROOT="/$M2D_LIB_DIR";
        fi
		
		M2D_LNX_DIST="redhat";
		rc=$(cat /etc/redhat-release | grep "Fedora");
		if [ -n "$rc" ]; then
			M2D_LNX_DIST="fedora";
		fi
		export M2D_LNX_DIST;
		
    fi
    export M2D_PKG_BLACKLIST="$M2D_APP_ROOT/blacklist/$M2D_LNX_DIST.lst";
}


###############################################################################
#main entry
###############################################################################
init_envs

#verify parameters
if [ ! -e "$M2D_APP_ROOT/plugins/m2d-$M2D_APP_NAME.sh" ]; then
	echo "[E001]Invalid APP_NAME.";
	print_usage;
	exit 1;
fi
if [ ! -d "$BUILD_ROOT" -o "$BUILD_ROOT" = "/" ]; then
    echo "[E001]Invalid BUILD_ROOT directory.";
	print_usage;
    exit 1;
fi

#clean build folder
mkdir -p "$BUILD_ROOT/.rpms";
rm -f $BUILD_ROOT/.rpms/*;
mkdir -p "$IMG_BASE";
rm -rf $IMG_BASE/*

#local library by package manager type
case "$M2D_LNX_TYPE" in
	redhat|suse)
		source $M2D_APP_ROOT/scripts/copy_rpm.sh
		;;
	ubuntu|debian)
	    echo "[E001]Platform is not supported.";
		;;
esac

#call plugin for specific application
source $M2D_APP_ROOT/plugins/m2d-$M2D_APP_NAME.sh
m2d_run;

#packaging to tar
CUR=$(pwd);

cd $IMG_BASE;

rm -f ../base.tar
tar -cf ../base.tar .

cd $CUR;

