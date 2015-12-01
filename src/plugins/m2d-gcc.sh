#!/bin/sh

#copy basic utilities first
copy_base_system;
copy_ssh_util;

#copy must-have modules
copy_pkg "make"
copy_pkg "gcc"

#copy optional modules
file=$(which g++ 2>/dev/null);
if [ "$?" == "0" ]; then
    pkg=$(rpm -qf "$file" | head -1);
	if [ "$?" = "0" ]; then
        copy_pkg "$pkg"
	else
	    copy_exe "$file";
	fi
fi
