#! /usr/bin/env bash

FILE="$1"
CCOPTS="-C -x c++ -std=c++11 -I include -I src"
G1="__________B $(date +%s) B__________"
G2="__________E $(date +%s) E__________"

function surround()
{
    egrep    "^# *include" "$FILE" | grep -v '\.hxx.$'
    echo "$G1"
    egrep -v "^# *include" "$FILE"
    echo "$G2"
}

egrep "^# *include" "$FILE" | grep -v '\.hxx.$'
surround                       \
    | cpp $CCOPTS -            \
    | sed -n -e "/$G1/,/$G2/p" \
    | sed "/$G1\|$G2\|^#/d"
