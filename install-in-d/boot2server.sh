#!/bin/bash
set -x
trap '[ "$?" -eq 0 ] || read -p "Looks like something went wrong in step ´$STEP´... Press any key to continue..."' EXIT

# TODO: I'm sure this is not very robust.  But, it is needed for now to ensure
# that binaries provided by Docker Toolbox over-ride binaries provided by
# Docker for Windows when launching using the Quickstart.
export PATH="/c/Program Files/Docker Toolbox:$PATH"
VM=${DOCKER_MACHINE_NAME-default}

cd "${DOCKER_TOOLBOX_INSTALL_PATH}"
DOCKER_MACHINE=./docker-machine.exe

STEP="Copy boot2docker.iso file."
cp ./boot2docker.iso ~/.docker/machine/cache

STEP="Looking for vboxmanage.exe"
if [ ! -z "$VBOX_MSI_INSTALL_PATH" ]; then
  VBOXMANAGE="${VBOX_MSI_INSTALL_PATH}VBoxManage.exe"
else
  VBOXMANAGE="${VBOX_INSTALL_PATH}VBoxManage.exe"
fi

BLUE='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m'

#clear all_proxy if not socks address
if  [[ $ALL_PROXY != socks* ]]; then
  unset ALL_PROXY
fi
if  [[ $all_proxy != socks* ]]; then
  unset all_proxy
fi

if [ ! -f "${DOCKER_MACHINE}" ]; then
  echo "Docker Machine is not installed. Please re-run the Toolbox Installer and try again."
  exit 1
fi

if [ ! -f "${VBOXMANAGE}" ]; then
  echo "VirtualBox is not installed. Please re-run the Toolbox Installer and try again."
  exit 1
fi

"${VBOXMANAGE}" list vms | grep \""${VM}"\" &> /dev/null
VM_EXISTS_CODE=$?

set -e

STEP="Checking if machine $VM exists"
if [ $VM_EXISTS_CODE -eq 1 ]; then
  "${DOCKER_MACHINE}" rm -f "${VM}" &> /dev/null || :
  rm -rf ~/.docker/machine/machines/"${VM}"
  #set proxy variables if they exists
  if [ "${HTTP_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env HTTP_PROXY=$HTTP_PROXY"
  fi
  if [ "${HTTPS_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env HTTPS_PROXY=$HTTPS_PROXY"
  fi
  if [ "${NO_PROXY}" ]; then
    PROXY_ENV="$PROXY_ENV --engine-env NO_PROXY=$NO_PROXY"
  fi
  "${DOCKER_MACHINE}" create -d virtualbox $PROXY_ENV "${VM}"
fi

STEP="Setting vm sharefolder in d:\Users"
if [ ! -d "/d/Users" ]; then
  echo "/d/Users not exists, now creating..."
  mkdir -p /d/Users
fi

"${DOCKER_MACHINE}" stop "${VM}"
"${VBOXMANAGE}" sharedfolder add "${VM}" --name 'd/Users' --hostpath d:\\Users --automount

STEP="Checking status on $VM"
VM_STATUS="$(${DOCKER_MACHINE} status ${VM} 2>&1)"
if [ "${VM_STATUS}" != "Running" ]; then
  "${DOCKER_MACHINE}" start "${VM}"
  yes | "${DOCKER_MACHINE}" regenerate-certs "${VM}"
fi

STEP="Setting env"
eval "$(${DOCKER_MACHINE} env --shell=bash --no-proxy ${VM})"

docker () {
  MSYS_NO_PATHCONV=1 docker.exe "$@"
}
export -f docker

STEP="Checking if exists base images"
#根据需要导入的基础镜像进行检测
# docker images | grep -q "game_server"
# BASECODE=$?


# if [ $BASECODE -eq 1 ]; then
#   echo "Load base game_server images."
#   cd /c/Users 
#   docker load < game_server.tar
# fi

echo "Load base game_server images."
cd /d/Users 
docker load < game_server.tar

STEP="Start All Server"
#删除所有容器，重新启动
# docker rm ${docker ps -a -q}

docker run -d --name gameserver game_server

STEP="Finalize"
clear
cat << EOF


                        ##         .
                  ## ## ##        ==
               ## ## ## ## ##    ===
           /"""""""""""""""""\___/ ===
      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~~ ~ /  ===- ~~~
           \______ o           __/
             \    \         __/
              \____\_______/

EOF
echo -e "${BLUE}docker${NC} is configured to use the ${GREEN}${VM}${NC} machine with IP ${GREEN}$(${DOCKER_MACHINE} ip ${VM})${NC}"
echo "For help getting started, check out the docs at https://docs.docker.com"
echo
cd

exec "$BASH" --login -i
