#!/bin/bash

if [ "$(id -u)" != "0" -a -z "$SUDO" ]
then
	echo "This script must be run as root" 1>&2
	exit 1
fi

echo "install osrm-backend? (ctrl+c to abort)"
read a

apt-get -y install libboost-system1.54.0 libboost-filesystem1.54.0 libboost-program-options1.54.0 libboost-thread1.54.0 libboost-regex1.54.0 libexpat1 libluabind0.9.1 liblua5.2-0 libstxxl1 libtbb2
dpkg -i osrm-backend_20160219-1_amd64.deb

echo "done."
dpkg -L osrm-backend | grep bin
