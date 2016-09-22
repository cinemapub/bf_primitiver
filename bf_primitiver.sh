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
  case $2 in
    0)  outmp4=$outdir/$bname.mix.mp4 ;;
    1)  outmp4=$outdir/$bname.tri.mp4 ;;
    2)  outmp4=$outdir/$bname.rec.mp4 ;;
    3)  outmp4=$outdir/$bname.ell.mp4 ;;
    4)  outmp4=$outdir/$bname.cir.mp4 ;;
    5)  outmp4=$outdir/$bname.rot.mp4 ;;
  esac
  if [ ! -f $outmp4 ] ; then
    echo "* Generate frames ..."
    uniq=$bname.$$
    $primitive -i "$1" -r 256 -o $tmpdir/$uniq.%04d.png -n $n -m $2
    echo "* Compile to $outmp4 ..."
    ffmpeg -r 50 -i $tmpdir/$uniq.%04d.png -b:v 5M -r 25 -y $outmp4 2> /dev/null
    echo "* Cleanup ..."
    rm $tmpdir/$uniq.*.png
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
