#!/bin/bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
   echo "usage: `basename $0` [-rc ~/.bashrc] <CSV2RDF4LOD_var>"
   exit 1
fi

rc="~/.bashrc"
if [[ "$1" == "-rc" && $# -ge 2 ]]; then
   rc="$2"
   shift 2
fi

var="CSV2RDF4LOD_HOME"
if [[ $# -gt 0 ]]; then
   var="$2"
   shift
fi

for sourceme in `grep "^source .*csv2rdf4lod-source-me*" $rc | awk '{print $2}'`; do 
   grep -H $var $sourceme
done
