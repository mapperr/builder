#! /bin/bash

DIR=`readlink -f $0`
`dirname $DIR`/core/builder.sh $@
