#!/bin/bash

PREFIX="/usr/local"

echo "PREFIX: $PREFIX"
echo "uninstall osrm-backend? ctrl+c to abort"
read a

sudo rm -rf "$PREFIX"/include/osrm/
sudo rm -f "$PREFIX"/bin/osrm-*
sudo rm -f "$PREFIX"/lib/libosrm*
sudo rm -f "$PREFIX"/lib/pkgconfig/libosrm.pc
