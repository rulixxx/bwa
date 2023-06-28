#!/bin/bash

set -xe

get_distro () {
  EXT=""
  if [[ $2 == *.tar.bz2* ]] ; then
    EXT="tar.bz2"
  elif [[ $2 == *.zip* ]] ; then
    EXT="zip"
  elif [[ $2 == *.tar.gz* ]] ; then
    EXT="tar.gz"
  elif [[ $2 == *.tgz* ]] ; then
    EXT="tgz"
  else
    echo "I don't understand the file type for $1"
    exit 1
  fi
  rm -f $1.$EXT
  if hash curl 2>/dev/null; then
    curl --retry 10 -sS -o $1.$EXT -L $2
  else
    wget --tries=10 -nv -O $1.$EXT $2
  fi
}


if [[ -z "${TMPDIR}" ]]; then
  TMPDIR=/tmp
fi

set -u

if [ "$#" -lt "1" ] ; then
  echo "Please provide an installation path such as /opt/ICGC"
  exit 1
fi

# get path to this script
SCRIPT_PATH=`dirname $0`;
SCRIPT_PATH=`(cd $SCRIPT_PATH && pwd)`

# get the location to install to
INST_PATH=$1
mkdir -p $1
INST_PATH=`(cd $1 && pwd)`
echo $INST_PATH

# get current directory
INIT_DIR=`pwd`

CPU=`grep -c ^processor /proc/cpuinfo`
if [ $? -eq 0 ]; then
  if [ "$CPU" -gt "8" ]; then
    CPU=8
  fi
else
  CPU=1
fi
echo "Max compilation CPUs set to $CPU"

SETUP_DIR=$INIT_DIR/install_tmp
mkdir -p $SETUP_DIR/distro # don't delete the actual distro directory until the very end
mkdir -p $INST_PATH/bin
cd $SETUP_DIR

echo -n "Building libdeflate ..."
if [ -e $SETUP_DIR/libdeflate.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  mkdir -p libdeflate
  get_distro "libdeflate" "https://github.com/ebiggers/libdeflate/archive/$VER_LIBDEFLATE.tar.gz"
  tar --strip-components 1 -C libdeflate -zxf libdeflate.tar.gz
  cd libdeflate
  cmake -B build
  cmake --build build
  cmake --install build
  cmake --install build --prefix $INST_PATH
  cd $SETUP_DIR
  rm -r libdeflate.tar.gz
  touch $SETUP_DIR/libdeflate.success
fi

echo -n "Building htslib ..."
if [ -e $SETUP_DIR/htslib.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  mkdir -p htslib
  get_distro "htslib" "https://github.com/samtools/htslib/releases/download/$VER_HTSLIB/htslib-$VER_HTSLIB.tar.bz2"
  tar --strip-components 1 -C htslib -jxf htslib.tar.bz2
  cd htslib
  export CFLAGS="-I$INST_PATH/include"
  export LDFLAGS="-L$INST_PATH/lib"
  ./configure --disable-plugins  --enable-libcurl --with-libdeflate --prefix=$INST_PATH
  make -j$CPU
  make install
  mkdir $INST_PATH/include/cram
  cp ./cram/*.h $INST_PATH/include/cram/
  cp header.h $INST_PATH/include
  cd $SETUP_DIR
  rm -r htslib.tar.bz2
  unset CFLAGS
  unset LDFLAGS
  unset LIBS
  touch $SETUP_DIR/htslib.success
fi

echo -n "Building samtools ..."
if [ -e $SETUP_DIR/samtools.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  rm -rf samtools
  get_distro "samtools" "https://github.com/samtools/samtools/releases/download/$VER_SAMTOOLS/samtools-$VER_SAMTOOLS.tar.bz2"
  mkdir -p samtools
  tar --strip-components 1 -C samtools -xjf samtools.tar.bz2
  cd samtools
  ./configure --with-htslib=$SETUP_DIR/htslib --enable-plugins --enable-libcurl --prefix=$INST_PATH
  make -j$CPU
  make install
  cd $SETUP_DIR
  rm -f samtools.tar.bz2
  touch $SETUP_DIR/samtools.success
fi


## build BWA (tar.gz)
if [ ! -e $SETUP_DIR/bwa.success ]; then
  rm -rf distro
  get_distro "distro" https://github.com/lh3/bwa/archive/${VER_BWA}.tar.gz
  mkdir distro
  tar --strip-components 1 -C distro -zxf distro.tar.gz
  sed -i '33d' ./distro/rle.h #hack to get it to complile with  gcc10
  make -C distro -j$CPU
  cp distro/bwa $INST_PATH/bin/.
  rm -rf distro.* distro/*
  touch $SETUP_DIR/bwa.success
fi

## build BWA-mem2 (tar.gz)
if [ ! -e $SETUP_DIR/bwa2.success ]; then
  rm -rf distro
  git clone --recursive https://github.com/bwa-mem2/bwa-mem2 distro
  cd distro
  #git checkout $BWAMEM2_TAG #checkout current master, 2.2.1 does not complite with gcc10
  make -j$CPU multi
  cp bwa-mem2* $INST_PATH/bin/.
  cd ../
  rm -rf distro.* distro/*
  touch $SETUP_DIR/bwa2.success
fi

## io_lib
echo -n "Building io_lib ..."
if [ -e $SETUP_DIR/io_lib.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  rm -rf samtools
  get_distro "distro" "https://github.com/jkbonfield/io_lib/releases/download/io_lib-1-15-0/io_lib-1.15.0.tar.gz"
  mkdir -p distro
  tar --strip-components 1 -C distro -xzf distro.tar.gz
  cd distro
  ./configure --with-libdeflate=$INST_PATH/lib/ --prefix=$INST_PATH
  make -j$CPU
  make install
  cd $SETUP_DIR
  rm -f distro.tar.bz2
  touch $SETUP_DIR/io_lib.success
fi

## libmaus2
echo -n "Building libmaus2 ..."
if [ -e $SETUP_DIR/libmaus2.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  rm -rf samtools
  get_distro "distro" "https://gitlab.com/german.tischler/libmaus2/-/archive/2.0.813-release-20221210220409/libmaus2-2.0.813-release-20221210220409.tar.gz"
  mkdir -p distro
  tar --strip-components 1 -C distro -xzf distro.tar.gz
  cd distro
  ./configure --with-libdeflate --with-io_lib=$INST_PATH --prefix=$INST_PATH
  make -j$CPU
  make install
  cd $SETUP_DIR
  rm -f distro.tar.bz2
  touch $SETUP_DIR/io_lib.success
fi

## biobambam2
echo -n "Building biobambam2 ..."
if [ -e $SETUP_DIR/biobambam2.success ]; then
  echo " previously built ...";
else
  echo
  cd $SETUP_DIR
  rm -rf samtools
  get_distro "distro" "https://gitlab.com/german.tischler/biobambam2/-/archive/2.0.185-release-20221211202123/biobambam2-2.0.185-release-20221211202123.tar.gz"
  mkdir -p distro
  tar --strip-components 1 -C distro -xzf distro.tar.gz
  cd distro
  ./configure --with-libmaus2=$INST_PATH --prefix=$INST_PATH
  make -j$CPU
  make install
  cd $SETUP_DIR
  rm -f distro.tar.bz2
  touch $SETUP_DIR/biobambam2.success
fi

cd $HOME
