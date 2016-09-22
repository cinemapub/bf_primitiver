#!/bin/bash

if [ "$1" == "" ] ; then
  echo "Usage: $0 [file]" >&2
  exit
fi

primitive="$HOME/go/bin/primitive"
iterations=1000

generate(){
  bname=$(basename $1 .jpg)
  outdir=$(dirname $1)
  outdir="$outdir.prim"
  if [ ! -d $outdir ] ; then
    mkdir $outdir
  fi
  tmpdir=/tmp/primitive
  if [ ! -d $tmpdir ] ; then
    mkdir $tmpdir
  fi
  n=$3
  if [ -z "$n" ] ; then
    n=100
  fi
  ext=mov
  case $2 in
    0)  outmp4=$outdir/$bname.mix.$ext ;;
    1)  outmp4=$outdir/$bname.tri.$ext ;;
    2)  outmp4=$outdir/$bname.rec.$ext ;;
    3)  outmp4=$outdir/$bname.ell.$ext ;;
    4)  outmp4=$outdir/$bname.cir.$ext ;;
    5)  outmp4=$outdir/$bname.rot.$ext ;;
  esac
  if [ ! -f $outmp4 ] ; then
    T1=$(date +%s);

    echo "--- $outmp4 ---"
    echo "* Generate frames ..."
    uniq=$bname
    tmpfiles=$tmpdir/$uniq.%04d.png
    $primitive -i "$1" -r 256 -s 1080 -o $tmpfiles -n $n -m $2
    T2=$(date +%s);

    echo "* Compile to $outmp4 ..."
    ffmpeg -r 50 -i $tmpfiles -b:v 5M -r 25 -y $outmp4 2> /dev/null
    T3=$(date +%s);

    echo "* Cleanup ..."
    rm $tmpdir/$uniq.*.png
    T4=$(date +%s);
    SECS=$((T4-T1))
    echo "* $SECS seconds to create the MOV"
  fi
}

if [ -f "$1" ] ; then
  generate $1 0 $iterations
fi

if [ -d "$1" ] ; then
  for jpg in $1/*.jpg ; do
    namehex=$(echo $jpg | md5sum | cut -c1-2)
    namedec=$((16#$namehex))
    method=$(expr $namedec % 6)
    echo "# $(basename $jpg) ---"
    generate $jpg $method $iterations
    if [ $method -gt 0 ] ; then
      generate $jpg 0 $iterations
    fi
  done
fi
