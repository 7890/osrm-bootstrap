#!/bin/bash

#https://github.com/Project-OSRM/osrm-backend
#https://github.com/Project-OSRM/osrm-backend/wiki/Server-api

#//tb/160219
#this script is a bit rough ("extended" notes on how to setup osrm-backend for routing)
#it might need adjustments for your linux flavour (see "init_build_env", "prepare_and_do_build")

FULLPATH="`pwd`/$0"
DIR=`dirname "$FULLPATH"`

OSRM_PORT=8088
OSM_PBF_URL="http://download.geofabrik.de/europe/andorra-latest.osm.pbf"
OSM_PBF_FILENAME="andorra-latest.osm.pbf"
#OSM_PBF_URL="http://download.geofabrik.de/europe/switzerland-latest.osm.pbf"
#OSM_PBF_FILENAME="switzerland-latest.osm.pbf"

CMAKE_INSTALL_PREFIX="/usr"

arch_=`uname -m`
if [ x"$arch_"  = "xx86_64" ]
then
	arch_handle=amd64
else
	arch_handle=i386
fi

#==============================================================
function init_build_env()
{
	echo "creating build environment `date`"

	echo $arch_handle
	sudo apt-get install cowbuilder util-linux
	sudo mkdir -p /var/cache/pbuilder/trusty-${arch_handle}

	time sudo cowbuilder --create --basepath /var/cache/pbuilder/trusty-${arch_handle}/base.cow --distribution trusty --mirror "http://ch.archive.ubuntu.com/ubuntu/" --components "main universe" --debootstrapopts --arch --debootstrapopts ${arch_handle}

	echo "done. `date`"
}

#==============================================================
function copy_build_script()
{
	echo "copying build script to /var/tmp"
	sudo cp "$FULLPATH" /var/tmp
}

#==============================================================
function login_build_env()
{
	echo "logging in to build environment"
	#login
	sudo cowbuilder --login --bindmounts /var/tmp --basepath /var/cache/pbuilder/trusty-${arch_handle}/base.cow
}

#==============================================================
function prepare_and_do_build()
{
	#we're supposed to be root

	echo "preparing build `date`"

	cd /root

	#inside chroot:
	apt-get -y install build-essential git autoconf automake libtool pkg-config wget unzip ed cmake ca-certificates ne dos2unix locate zip rsync checkinstall
	apt-get -y install libboost-all-dev libtbb-dev libluabind-dev libstxxl-dev libbz2-dev

	#for ccache
	mkdir -p /home/build
	export HOME=/home/build

	#get osrm software
#	git clone https://github.com/Project-OSRM/osrm-backend
	#the official repo seems to be too new / does not compile anymore with current setup so using snapshot
	git clone https://github.com/7890/osrm-backend
	cd osrm-backend/cmake

	#configure and build
	time cmake -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX" .. && time make

	echo "done. `date`"
}

#==============================================================
function get_osm_data()
{
	echo "downloading osm data `date`"

	cd /root/osrm-backend/cmake || return

	#get osm geo data
	wget "$OSM_PBF_URL"

	#use default configuration
	ln -s ../profiles/car.lua profile.lua
	ln -s ../profiles/lib/

	#indirection, all outputfiles will be named map.*
	ln -s "$OSM_PBF_FILENAME" map.pbf

	echo "done. `date`"
}

#==============================================================
function prepare_osm_data()
{
	echo "preparing osm data `date`"

	cd /root/osrm-backend/cmake || return

	#prepare for use
	time ./osrm-extract map.pbf && time ./osrm-prepare map.osrm

	echo "done. `date`"
}

#==============================================================
function serve_osrm_data()
{
	echo "serving osrm data on port $OSRM_PORT `date`"

	cd /root/osrm-backend/cmake || return

	#serve
	./osrm-routed -p "$OSRM_PORT" map.osrm
}

#==============================================================
function do_all_logged_in()
{
	#from within logged-in chroot
	prepare_and_do_build
	get_osm_data
	prepare_osm_data
	serve_osrm_data
}

#==============================================================
function test_service()
{
	wget -O- -q "http://127.0.0.1:8088/nearest?loc=47,8&compression=false"
}

#==============================================================
function create_debian_package()
{
	echo "creating .deb with checkinstall `date`"

	cd /root/osrm-backend/cmake || return

	REQUIRES="libboost-system1.54.0,libboost-filesystem1.54.0,libboost-program-options1.54.0,libboost-thread1.54.0,libboost-regex1.54.0,libexpat1,libluabind0.9.1,liblua5.2-0,libstxxl1,libtbb2"

	checkinstall --pkgname osrm-backend --pkggroup geo --pkgsource "https://github.com/Project-OSRM/osrm-backend" --provides osrm-backend --requires "$REQUIRES" make install

	echo "done. `date`"
}

#==============================================================
function test_debian_package_in_chroot()
{
	#we're supposed to be root

	echo "testing debian package `date`"

	cd /root

	#inside chroot:
	apt-get -y install git wget ne ca-certificates

	#get osrm-bootstrap software
	git clone https://github.com/7890/osrm-bootstrap
	cd osrm-bootstrap/dist

	./install.sh

	wget "$OSM_PBF_URL"

	#use default configuration
	ln -s ../profiles/car.lua profile.lua

	#indirection, all outputfiles will be named map.*
	ln -s "$OSM_PBF_FILENAME" map.pbf

	time osrm-extract map.pbf && time osrm-prepare map.osrm && osrm-routed --trial -p "$OSRM_PORT" map.osrm

	echo "done. `date`"
}

#==============================================================
#==============================================================

echo "please read the script before proceeding."
echo ""
echo "your choices:"
echo "1: init_build_env"
echo "2: copy_build_script"
echo "3: login_build_env"
echo "4: prepare_and_do_build"
echo "5: get_osm_data"
echo "6: prepare_osm_data"
echo "7: serve_osrm_data"
echo "8: do tasks 4,5,6,7"
echo "9: test_service"
echo "10: create_debian_package"
echo "11: test_debian_package_in_chroot"
echo ""
echo -n "proceed? ctrl+c to abort or choice (number): "
read input

if [ x"$input" = "x1" ]
then
	init_build_env
	exit
fi

if [ x"$input" = "x2" ]
then
	copy_build_script
	exit
fi

if [ x"$input" = "x3" ]
then
	login_build_env
	exit
fi

if [ x"$input" = "x4" ]
then
	prepare_and_do_build
	exit
fi

if [ x"$input" = "x5" ]
then
	get_osm_data
	exit
fi

if [ x"$input" = "x6" ]
then
	prepare_osm_data
	exit
fi

if [ x"$input" = "x7" ]
then
	serve_osrm_data
	exit
fi

if [ x"$input" = "x8" ]
then
	do_all_logged_in
	exit
fi

if [ x"$input" = "x9" ]
then
	test_service
	exit
fi

if [ x"$input" = "x10" ]
then
	create_debian_package
	exit
fi

if [ x"$input" = "x11" ]
then
	test_debian_package_in_chroot
	exit
fi

exit
#==============================================================
#==============================================================

#once
init_build_env

copy_build_script
login_build_env
#from within logged-in chroot
prepare_and_do_build
get_osm_data
prepare_osm_data
serve_osrm_data
test_service
create_debian_package


[info] starting up engines, v4.9.0
[info] populating base path: map.osrm
[info] HSGR file:	"map.osrm.hsgr"
[info] loading graph data
[info] loading graph from map.osrm.hsgr
[info] number_of_nodes: 1332835, number_of_edges: 5773210
[info] loaded 1332835 nodes and 5773210 edges
[info] Data checksum is 1909209696
[info] loading edge information
[info] loading core information
[info] loading geometries
[info] loading timestamp
[info] Loading Timestamp
[info] loading street names
[info] loaded plugin: table
[info] loaded plugin: hello
[info] loaded plugin: nearest
[info] loaded plugin: match
[info] loaded plugin: timestamp
[info] loaded plugin: viaroute
[info] loaded plugin: trip
[info] http 1.1 compression handled by zlib version 1.2.8
[info] running and waiting for requests
