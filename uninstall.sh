#!/bin/bash

if [ "$(id -u)" != "0" -a -z "$SUDO" ]
then
	echo "This script must be run as root" 1>&2
	exit 1
fi

PREFIX="/usr/local"

echo "PREFIX: $PREFIX"
echo "uninstall osrm-backend? ctrl+c to abort"
read a

rm -rf "$PREFIX"/include/osrm/
rm -f "$PREFIX"/bin/osrm-*
rm -f "$PREFIX"/lib/libosrm*
rm -f "$PREFIX"/lib/pkgconfig/libosrm.pc
