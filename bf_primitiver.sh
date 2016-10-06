#!/bin/bash

if [ "$1" == "" ] ; then
  echo "Usage: $0 [file/folder]" >&2
  exit
fi

primitive="$HOME/go/bin/primitive"
iterations=$2
if [ -z "$iterations" ] ; then
  iterations=1000
fi

nbgroups=5
maxpixels=1600
outfps=30
tmpdir=/h/TEMP/primitive
if [ ! -d $tmpdir ] ; then
  mkdir $tmpdir
fi

generate(){
  bname=$(basename $1 .jpg)
  outdir=$(dirname $1)
  outdir="$outdir.prim"
  if [ ! -d $outdir ] ; then
    mkdir $outdir
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

    uniq=$bname
    tmpfiles=$tmpdir/$uniq.all.%04d.png
    selfiles=$tmpdir/$uniq.sel.%04d.png
    rm -f $tmpdir/$uniq.*.png
    resized=$tmpdir/$uniq.resized.png
    convert "$1" -resize 1080x1920 -background black -gravity center -extent 1080x1920 -resize ${maxpixels}x${maxpixels} "$resized"

    #--- STEP 1
    echo "> CREATE $n FRAMES OF $bname"
    $primitive -i "$resized" -r 256 -s $maxpixels -o $tmpfiles -n $n -m $2 -a 40
    T2=$(date +%s);
    SECS=$((T2-T1))
    FPS=$(expr $n / $SECS)
    echo "  in $SECS seconds ($FPS fps)"

    #--- STEP 2
    echo "> ADAPT FPS"
    selno=0
    groupsize=$(expr $n / $nbgroups)
    echo "  input  = $n frames (in groups of $groupsize)"
    for i in $(seq 1 $n) ; do
      infile=$(printf "$tmpfiles" $i)
      # decide if frame should be taken
      select=1
      groupno=$(expr $i / $groupsize + 1)
      if [ $(expr $i % $groupno ) -gt 0 ] ; then
        select=0
      fi
      if [ $select -gt 0 ] ; then
        selno=$(expr $selno + 1)
        outfile=$(printf "$selfiles" $selno)
        mv $infile $outfile
      else
        # just delete
        rm $infile
      fi
    done
    echo "  output = $selno frames"

    #--- STEP 2
    fadesec=2
    fadeframes=$(expr $fadesec \* $outfps)

    echo "> ADD $fadeframes FRAMES OF FADE"
    lastanim=$outfile
    for f in $(seq 1 $fadeframes) ; do
      selno=$(expr $selno + 1)
      togo=$(expr $fadeframes - $f)
      blend=$(expr 100 \* $togo / $fadeframes)
      outfile=$(printf "$selfiles" $selno)
      composite -blend $blend "$lastanim" "$resized" "$outfile"
    done

    T3=$(date +%s);
    SECS=$((T3-T2))
    FPS=$(expr $n / $SECS)
    echo "  output = $selno frames"
    echo "  in $SECS seconds ($FPS fps)"

    #--- STEP 4
    echo "> ADD $fadeframes FRAMES OF ORIGINAL"
    for f in $(seq 1 $fadeframes) ; do
      selno=$(expr $selno + 1)
      outfile=$(printf "$selfiles" $selno)
      cp "$resized" "$outfile"
    done
    echo "  output = $selno frames"
    T4=$(date +%s);
    SECS=$((T4-T3))
    FPS=$(expr $selno / $SECS)
    echo "  in $SECS seconds ($FPS fps)"

    #--- STEP 5
    echo "> COMPILE $(basename $outmp4) ..."
    estimlength=$(expr $selno / $outfps)
    ffmpeg -r $outfps -i $selfiles -b:v 8M -r $outfps -y $outmp4 2> /dev/null
    T5=$(date +%s);
    SECS=$((T5-T4))
    FPS=$(expr $selno / $SECS)
    echo "  in $SECS seconds ($FPS fps)"
    movlength=$(ffmpeg -i $outmp4 2>&1 | grep Duration | cut -d',' -f1 | cut -d':' -f4-)
    echo "  estimated length: $estimlength - real length = $movlength sec"
    echo "#----------------------------"

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
    echo "# $(basename $jpg)"
    generate $jpg $method $iterations
    if [ $method -gt 0 ] ; then
      generate $jpg 0 $iterations
    else
      generate $jpg 3 $iterations
    fi
  done
fi
