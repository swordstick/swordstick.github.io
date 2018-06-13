#!/bin/bash
# Author: Robin Wen
# Date: 11:44:56 2015-03-10.
# Desc: Auto push after update the repo using bash.

while getopts :ac:p ARGS
do
case $ARGS in
    a)  
		git add -A .
        ;;
    c)  
		git commit -m "$OPTARG"
        ;;
    p)  
		git push origin master
        ;;
     *)  
    	echo $"Usage: $0 {-a(express add)|-c(express commit) update_info|-p(express push)}"
		exit 2
        ;;
esac
done

shift $[ $OPTIND -1 ]
param_index=1
for param in "$@"
do
    echo "Parameter $param_index:$param"
    param_index=$[ $param_index + 1 ]
done
