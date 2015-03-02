#! /bin/bash

DIR=`readlink -f $0`
`dirname $DIR`/bin/builder.sh $@
