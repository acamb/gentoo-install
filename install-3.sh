#!/bin/bash
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND; echo "\033[32m Executing $current_command \033[0m"' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
source /etc/profile

#At this point you may want to rebuild all the packages in stage 3 tarball before proceeding
emerge -e @world

emerge $(< myPackages.list)
rc-update add dbus default
rc-update add display-manager default
echo XSESSION=\"Xfce4\" > /etc/env.d/90xsession
env-update && source /etc/profile
