
check_blacklist()
{
    local name=$1;
    local rc="";
    local item="";

    [ ! -e "$M2D_PKG_BLACKLIST" ] && { return 0; }

    while read item
    do
        [ -z "$item" ] && continue;

        [ "$item" = "$name" ] && return 1;

        rc=$(echo $name | grep "^$item-" 2>/dev/null);
        [ -n "$rc" ] && return 1;
    done < <(cat "$M2D_PKG_BLACKLIST");
    return 0;
}

copy_file()
{
    local file=$1;
    local dir="";

    dir=$(dirname "$file");
    dir=$(readlink -f "$dir");
    mkdir -p "$IMG_BASE/$dir";

    if [ -d "$file" -a ! -h "$file" ]; then
        [ ! -d "$IMG_BASE/$file" ] && mkdir "$IMG_BASE/$file";
    elif [ -f "$file" -o -h "$file" ]; then
        cp -fP "$file" "$IMG_BASE/$dir/";
    fi
}

copy_rpm_dep_file()
{
	local file=$1;
	local real="";
	local pkg="";
	
	pkg=$(rpm -qf "$file");
	if [ "$?" = "0" ]; then
		copy_rpm "$pkg";
	else
		copy_file "$file";
		real=$(readlink -f "$file");
		if [ "$real" != "$file" ]; then
			pkg=$(rpm -qf "$real");
			if [ "$?" = "0" ]; then 
			    copy_rpm "$pkg";
			else
			    copy_file "$real";
			fi
		fi
	fi
}

copy_rpm()
{
    local name=$1;
	local file="";
	local dir="";
	local pkg="";
	
    #check if the package has been installed.
	name=$(rpm -q $name);
    if [ "$?" != "0" ]; then
        echo "[W001]Failed to find rpm package: $name.";
        return;
    fi

    #sometimes, rpm may return multiple lines result 
    name=$(echo "$name" | head -1);
	
    #check if the package has already been processed.
	if [ -f "$BUILD_ROOT/.rpms/$name" ]; then
	    return;
	fi
    
    #check if the package is in black list
    check_blacklist "$name";
    if [ "$?" != "0" ]; then
        echo "[I002]Skip package $name because it matches blacklist file.";
        return;
    fi

	touch "$BUILD_ROOT/.rpms/$name";
	echo "[I001]Processing rpm package $name ...";
	
	#copy all files owned by the rpm package
	#exclude device file
	while read file
	do
	    [ ! -e "$file" ] && continue;
	    copy_file "$file"
	done < <(rpm -ql $name | grep -v "^/usr/share");
	
	#copy dependency packages
	local arch=$(rpm -q --qf="[%{ARCH}\\n]" "$name");
	while read file
	do
		#it's full path of a file
	    if [ -e "$file" ]; then
			if [ ! -e "$IMG_BASE/$file" ]; then
				pkg=$(rpm -qf "$file");
				copy_rpm "$pkg";
			fi
			continue;
		fi
		
		#it's name of a rpm package
		pkg=$(rpm -q "$file" | head -1);
		if [ "$?" = "0" ]; then
		    copy_rpm "$pkg";
			continue;
		fi
		
		#cut the string 
		file=$(echo "$file" | awk -F\( '{print $1}' );
		
		#it's name of a rpm package
		pkg=$(rpm -q "$file" | head -1);
		if [ "$?" = "0" ]; then
		    copy_rpm "$pkg";
			continue;
		fi
		
		#it's name of a library file
		if [ "$arch" = "x86_64" ]; then
		    file=$(ldconfig -p | grep "$file" | grep "x86-64" | awk '{print $4}' | head -1);
		else
		    file=$(ldconfig -p | grep "$file" | grep -v "x86-64" | awk '{print $4}' | head -1);
		fi
		#file="$M2D_LIB_ROOT/$file";
		if [ -e "$file" ]; then
			if [ ! -e "$IMG_BASE/$file" ]; then
                copy_rpm_dep_file "$file";
			fi
			continue;
		fi
		
	done < <(rpm -q --qf "[%{REQUIRENAME}\\n]" $name | grep -v "^rpmlib");
}


copy_exe()
{
	local tgt=$1
	local file="";
	local dir="";
	
	dir=$(dirname "$tgt");
	mkdir -p $IMG_BASE/$dir;
	cp -fP "$tgt" $IMG_BASE/$dir/;
	if [ -h "$tgt" ]; then
		file=$(readlink -f "$tgt");
		dir=$(dirname $file);
		mkdir -p $IMG_BASE/$dir;
		cp -fP $file $IMG_BASE/$dir/;
	fi

	ldd "$tgt" | awk  '{print $3}' | while read file
	do
		[ -z "$file" ] && continue;
		[ ! -e "$file" ] && { echo "Skip non-existing file $file."; continue; }
		dir=$(dirname $file);
		dir=$(readlink -f $dir);
		mkdir -p $IMG_BASE/$dir;
		cp -fP $file $IMG_BASE/$dir/;
		if [ -h $file ]; then
			file=$(readlink -f $file);
			dir=$(dirname $file);
			dir=$(readlink -f $dir);
			mkdir -p "$IMG_BASE/$dir";
			cp -fP "$file" "$IMG_BASE/$dir";
		fi
	done;
}


FILE_LST=$(cat <<'EOF'
strace
EOF
);

#make pipe line fail immediately once any of member command fails
set -o pipefail;


while read file;
do
    file=$(which "$file");
	[ ! -e "$file" ] && { echo "Skip non-existing file $file."; continue; }
	
	copy_exe "$file";
done <<<"$FILE_LST";

#for base system
copy_rpm "filesystem";
copy_rpm "setup";
copy_rpm "coreutils";
copy_rpm "passwd"
copy_rpm "bash"
copy_rpm "shadow-utils"


#for network
copy_rpm "openssh-clients"
copy_rpm "openssh-server"
copy_rpm "net-tools"
copy_rpm "hostname"
cp -rfpP /etc/ssh "$IMG_BASE/etc/"
cp -rfpP /root/.ssh "$IMG_BASE/root/"

#for rpm
copy_rpm "rpm";

#for useful tools
copy_rpm "vim-minimal"
copy_rpm "procps-ng"
copy_rpm "findutils"
copy_rpm "iputils"

