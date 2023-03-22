#!/bin/bash

rr="\033[0;31m"
gg="\033[0;32m"
bb="\033[0;34m"
yy="\033[0;33m"
uu="\033[4m"
ee="\033[0m"
r() { echo -e "$rr$@$ee" ; }
g() { echo -e "$gg$@$ee" ; }
b() { echo -e "$bb$@$ee" ; }
y() { echo -e "$yy$@$ee" ; }