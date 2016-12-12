#!/bin/bash -e
#     ___ ___ _  _ ___ ___    _ _____ ___ ___         
#    / __| __| \| | __| _ \  /_\_   _| __|   \        
#   | (_ | _|| .` | _||   / / _ \| | | _|| |) |       
#    \___|___|_|\_|___|_|_\/_/_\_\_|_|___|___/_ _____ 
#   |   \ / _ \  | \| |/ _ \_   _| | __|   \_ _|_   _|
#   | |) | (_) | | .` | (_) || |   | _|| |) | |  | |  
#   |___/ \___/  |_|\_|\___/ |_|   |___|___/___| |_|  
# 

RED="$(echo -e '\033[1;31m')"
NORM="$(echo -e '\033[0m')"

sudo echo -e "\nTesting sudo works...\n"

# We MUST be in the same directory as this script for the build to work properly
cd $(dirname $0)

function is_rhel()
{
  grep -qi 'Red Hat Enterprise Linux' /etc/redhat-release
  return $?
}

tmpfile=""

if ! is_rhel ; then
    tmpfile=$(mktemp Dockerfile-XXXXX)
    echo
    echo "Not rhel, enabling entitlement workaround:"
    echo
    echo "Downloading etc-pki-entitlement. ${RED}DO NOT CHECK THIS IN!!!${NORM}"
    scp -r tower.ops.rhcloud.com:/etc/pki/entitlement etc-pki-entitlement
    echo

    echo -n "Updating Dockerfile to include etc-pki-entitlement..."
    cp Dockerfile $tmpfile
    sed -i 's#FROM.*#&\nADD etc-pki-entitlement /etc-pki-entitlement#' Dockerfile
    echo "Done."
fi

# Build ourselves
echo
echo "Building oso-rhel7-ops-base..."
sudo time docker build $@ -t oso-rhel7-ops-base . && \
sudo docker tag oso-rhel7-ops-base docker-registry.ops.rhcloud.com/ops/oso-rhel7-ops-base
DOCKER_EXITCODE=$?

if ! is_rhel ; then
  echo
  echo "Not rhel, disabling entitlement workaround:"
  echo -n "Restoring original Dockerfile... "
  mv $tmpfile Dockerfile
  echo "Done."

  echo -n "Removing downloaded etc-pki-entitlement directory... "
  rm -rf etc-pki-entitlement
  echo "Done."
  echo
fi

# This shouldn't be needed since we're using -e, but apparently -e isn't working as expected.
if [ $DOCKER_EXITCODE -ne 0 ] ; then
  echo -e "\n${RED}ERROR: docker command failed.${NORM}\n"
  exit $DOCKER_EXITCODE
fi
