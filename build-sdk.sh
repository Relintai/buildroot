#!/bin/bash
set -e
 
function usage() {
  echo "usage: $0 host target"
  echo "  where host is one of linux-x86_64"
  echo "  where target is one of i686, x86_64, armv7, aarch64, armv6"
  exit 1
}

if [ -z $1 ] || [ -z $1 ]; then
  usage
fi

case $1 in
  linux-x86_64)
    host=$1
  ;;
  *)
    echo "unknown SDK host \"$1\""
    usage
esac

case $2 in
  i686)
    cp config-pandemonium-i686 .config
    toolchain_prefix=i686-pandemonium-linux-gnu
    target_toolchain_prefix=i686-pandemonium-linux-gnu
    bits=32
  ;;
  x86_64)
    cp config-pandemonium-x86_64 .config
    toolchain_prefix=x86_64-pandemonium-linux-gnu
    target_toolchain_prefix=x86_64-pandemonium-linux-gnu
    bits=64
  ;;
  armv7)
    cp config-pandemonium-armv7 .config
    toolchain_prefix=arm-pandemonium-linux-gnueabihf
    target_toolchain_prefix=armv7-pandemonium-linux-gnueabihf
    bits=32
  ;;
  aarch64)
    cp config-pandemonium-aarch64 .config
    toolchain_prefix=aarch64-pandemonium-linux-gnu
    target_toolchain_prefix=aarch64-pandemonium-linux-gnu
    bits=64
  ;;
  armv6)
    cp config-pandemonium-armv6 .config
    toolchain_prefix=arm-pandemonium-linux-gnueabihf
    target_toolchain_prefix=armv6-pandemonium-linux-gnueabihf
    bits=32
  ;;
  *)
    echo "unknown SDK target \"$2\""
    usage
  ;;
esac

if which podman &> /dev/null; then
  container=podman
elif which docker &> /dev/null; then
  container=docker
else
  echo "Podman or docker have to be in \$PATH"
  exit 1
fi

function build_linux_sdk() {
  ${container} build -f Dockerfile.linux-builder -t pandemonium-buildroot-builder-linux .
  ${container} run -it --rm -v $(pwd):/tmp/buildroot:z -w /tmp/buildroot -e FORCE_UNSAFE_CONFIGURE=1 pandemonium-buildroot-builder-linux bash -c "make clean; make syncconfig; make sdk"
  # --userns=keep-id

  mkdir -p pandemonium-toolchains

  rm -fr pandemonium-toolchains/${toolchain_prefix}_sdk-buildroot
  tar xf output/images/${toolchain_prefix}_sdk-buildroot.tar.gz -C pandemonium-toolchains

  pushd pandemonium-toolchains/${toolchain_prefix}_sdk-buildroot
  ../../clean-linux-toolchain.sh ${toolchain_prefix} ${bits}
  popd

  if [[ "$toolchain_prefix" != "$target_toolchain_prefix" ]]; then
    mv pandemonium-toolchains/${toolchain_prefix}_sdk-buildroot pandemonium-toolchains/${target_toolchain_prefix}_sdk-buildroot
  fi

  pushd pandemonium-toolchains
  tar -cjf ${target_toolchain_prefix}_sdk-buildroot.tar.bz2 ${target_toolchain_prefix}_sdk-buildroot
  rm -rf ${target_toolchain_prefix}_sdk-buildroot
  popd
}

build_linux_sdk

echo
echo "***************************************"
echo "Build succesful your toolchain is in the pandemonium-toolchains directory"
