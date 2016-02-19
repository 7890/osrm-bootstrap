This folder is copied from
https://github.com/Project-OSRM/osrm-backend
Sat Feb 20 00:18:45 CET 2016

profiles are used during the "osrm-extract" stage.

link a profile to the working directory named "profile.lua" or pass via cmdline argument.

i.e.

ln -s <path to profiles folder>/car.lua profile.lua
osrm-extract <map.pbf file>
