#! /bin/bash

DIR_SCRIPT=`dirname $0`
DIR_SCRIPT=`cd $DIR_SCRIPT; pwd -P` # builder/usr/script/antivy

DIR_BASE=`cd $DIR_SCRIPT; cd ../../..`


FILE_CONFIG="$DIR_BASE/core/builder.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "file di configurazione [$FILE_CONFIG] non trovato"
	exit 1
fi

source "$FILE_CONFIG"

SCRIPT_NAME=`basename $0`

# ---------------------------------------------------------
# functions
# ---------------------------------------------------------

helpmsg()
{
	echo "usage:"
	echo "$SCRIPT_NAME <path_root_progetto> <revision> <artifact_name> <artifact_type>"
}

# ---------------------------------------------------------
# exec
# ---------------------------------------------------------

if [ -z "$1" ]
then
	helpmsg
	exit 1
fi

DIR_ROOT_PROGETTO="$1"
REVISION="$2"
ARTIFACT_NAME="$3"
ARTIFACT_TYPE="$4"

if [ "$ARTIFACT_TYPE" = "runjar" ]; then

	TARGET="dist_runjar"

elif [ "$ARTIFACT_TYPE" = "jar" ]; then

	TARGET="dist_jar"
	
elif [ "$ARTIFACT_TYPE" = "war" ]; then

	TARGET="dist_war"
else

	echo "artifact_type [$ARTIFACT_TYPE] not supported"
	echo "supported artifact types: runjar, jar, war"
	exit 1
fi

if ! [ -z "$REVISION" ]
then
	REVISION_OPT="-Dvcs.revision=$REVISION"
fi

UUID_BUILD=`uuidgen`

if [ -z "$UUID_BUILD" ]
then
	TS=`date +'%Y%m%d%H%M%S'`
	PRJNAME=`basename $DIR_ROOT_PROGETTO`
	UUID_BUILD="$PRJNAME-$REVISION-$TS"
fi

DIR_BUILD="$DIR_BASE/tmp/$UUID_BUILD/build"
FILE_IVYSETTINGS="$DIR_SCRIPT/ivysettings.xml"
FILE_BUILDFILE="$DIR_SCRIPT/build.xml"
ANT_DIR_IVY="$BUILDER_DIR_PACKS/ivy"
ANT_DIR_DIST="$BUILDER_DIR_CACHE/$ARTIFACT_NAME/$REVISION"

test -d $ANT_DIR_DIST && rm -rf $ANT_DIR_DIST
mkdir -p $ANT_DIR_DIST

if [ "$OS" = "cygwin" ]
then
	DIR_BUILD=`cygpath -m $DIR_BUILD`
	FILE_BUILDFILE=`cygpath -m $FILE_BUILDFILE`
	FILE_IVYSETTINGS=`cygpath -m $FILE_IVYSETTINGS`
	DIR_ROOT_PROGETTO=`cygpath -m $DIR_ROOT_PROGETTO`
	ANT_DIR_IVY=`cygpath -m $DIR_IVY`
	ANT_DIR_DIST=`cygpath -m $DIR_DIST`
fi



echolog "esecuzione antwrapper per [$DIR_ROOT_PROGETTO]"
$DIR_ANT/bin/ant -lib "$ANT_DIR_IVY" -lib "$ANT_DIR_IVY/lib" -Dbuilder.ivy.settings="$FILE_IVYSETTINGS" -Divy.default.ivy.user.dir="$ANT_DIR_IVY" \
	-Dbuilder.dir.dist="$ANT_DIR_DIST" -Dbasedir="$DIR_ROOT_PROGETTO" -Ddir.build=$DIR_BUILD $REVISION_OPT -f "$FILE_BUILDFILE" $TARGET
exit $?