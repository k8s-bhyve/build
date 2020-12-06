#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
if [ -d ./workspace ]
then
 echo "The workspace is present!!!!!!"
else
 #wget $REPOSITORY/workspace.tar.gz
 #tar -xzvf workspace.tar.gz
 #rm -rf workspace.tar.gz
 mkdir -p workspace
fi
