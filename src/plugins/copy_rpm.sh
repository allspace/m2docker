
copy_rpm()
{
    local name=$1;
	local file="";
	local dir="";
	local pkg="";
	
	name=$(rpm -q $name);
	
	if [ -f "$BUILD_ROOT/.rpms/$name" ]; then
	    return;
	fi
	touch "$BUILD_ROOT/.rpms/$name";
	echo "Processing rpm package $name ...";
	
	rpm -ql $name | grep -v "^/usr/share" | while read file
	do
	    [ ! -e "$file" ] && continue;
		
		dir=$(dirname "$file");
		dir=$(readlink -f "$dir");
		mkdir -p "$IMG_BASE/$dir";
		
		if [ -d "$file" -a ! -h "$file" ]; then
		    [ ! -d "$IMG_BASE/$file" ] && mkdir "$IMG_BASE/$file";
		else
		    cp -fP "$file" "$IMG_BASE/$dir/";
		fi	
	done;
	
	#copy dependency packages
	rpm -qR $name | grep -v "^rpmlib" | while read file
	do
		#it's full path of a file
	    if [ -e "$file" ]; then
			if [ ! -e "$IMG_BASE/$file" ]; then
				pkg=$(rpm -qf "$file");
				copy_rpm $pkg;
			fi
			continue;
		fi
		
		#it's name of a rpm package
		pkg=$(rpm -q $file);
		if [ "$?" = "0" ]; then
		    copy_rpm $pkg;
			continue;
		fi
		
		#cut the string 
		file=$(echo "$file" | awk -F\( '{print $1}' );
		
		#it's name of a rpm package
		pkg=$(rpm -q $file);
		if [ "$?" = "0" ]; then
		    copy_rpm $pkg;
			continue;
		fi
		
		#it's name of a library file
		file="/usr/lib64/$file";
		if [ -e "$file" ]; then
			if [ ! -e "$IMG_BASE/$file" ]; then
				pkg=$(rpm -qf "$file");
				copy_rpm $pkg;
			fi
			continue;
		fi
		
	done;
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

#

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
copy_rpm "initscripts"

#for network
copy_rpm "openssh-clients"
copy_rpm "openssh-server"
copy_rpm "fipscheck-lib"
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

#for NFS client
copy_rpm "nfs-utils"
