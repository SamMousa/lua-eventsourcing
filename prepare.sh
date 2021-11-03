#!/bin/sh

# exit when any command fails
set -e

sed -i "s/{VERSION}/$1/g" LibEventSourcing.toc


# add deps
pipx install gitman
gitman install
# Remove git dirs
find libs -type d -name ".git" -execdir rm -rf {} \; -prune
mkdir LibEventSourcing
mv readme.MD LibEventSourcing/
mv source LibEventSourcing/
mv libs LibEventSourcing/
zip -r LibEventSourcing.zip LibEventSourcing