#! /bin/sh

cd `dirname $0`; cd ..
DIR_BASE=`pwd -P`

FILE_CONFIG="conf/builder.rc"

if ! [ -r "$FILE_CONFIG" ]
then
	echo "configuration file [$FILE_CONFIG] not found"
	exit 1
fi

source "$FILE_CONFIG"


# ---------------------------------------------------------
# setup
# ---------------------------------------------------------

test -f $FILE_DATABASE || touch $FILE_DATABASE


# ---------------------------------------------------------
# functions
# ---------------------------------------------------------

helpmsg()
{
	SCRIPT_NAME=`basename $0`
	echo ""
	echo "comandi:"
	echo ""
	echo "dist <nome_progetto> [revision] [path]"
	echo ""
	echo "		crea un jar o un war del progetto alla revision specificata (o alla head se omessa) e eventualmente lo copia nel path specificato"
	echo ""
	echo "auto"
	echo ""
	echo "		compila tutti i progetti all'ultima revision e li copia nella cartella [$DIR_DIST_AUTO]"
	echo ""
	echo "pub"
	echo ""
	echo "		compila e pubblica tutte le librerie censite nel file [$FILE_PROGETTI]"
	echo "		un progetto e' riconosciuto come libreria se e' censito con un nome che inizi con 'lib'"
	echo "		le librerie vengono compilate e pubblicate nell'ordine in cui sono censite nel file [$FILE_PROGETTI]"
	echo ""
	echo "ls"
	echo ""
	echo "		lista dei progetti disponibili contenuti nel file [$FILE_PROGETTI]"
	echo ""
	echo "clean"
	echo ""
	echo "		elimina file temporanei"
	echo ""
	echo "last"
	echo ""
	echo "		stampa il path dell'ultima build effettuata"
	echo ""
	echo "rev"
	echo ""
	echo "		get latest revision"
	echo ""
	echo "svn"
	echo ""
	echo "		wrapper per il client svn"
	echo ""
	echo "ant"
	echo ""
	echo "		wrapper per ant"
	echo ""
}

builder_getlastbuild()
{
	# su linux funziona, su mobaxterm no perche` e` un busybox e il find non ha l'azione "printf"
	#find "$DIR_DIST" -type f -printf "%A@ %p\n" | sort -n | tail -n1 | awk '{print $2}'
	
	NEWER=""
	
	for file in `find "$DIR_DIST" -type f`
	do
		if [ -z "$NEWER" ]
		then
			NEWER="$file"
		fi
		if [ `stat -c %Y $file` -gt `stat -c %Y $NEWER` ]
		then
			NEWER="$file"
		fi
	done
	
	echo "$NEWER"
}

builder_clean()
{
	echolog "eliminazione del contenuto della directory [$DIR_DIST]"
	
	if ! [ -d "$DIR_DIST" ]
	then
		echolog "la directory [$DIR_DIST] non esiste"
		return 1
	fi
	
	rm -rf $DIR_DIST/*
	if [ $? -ne 0 ]
	then
		echolog "impossibile eliminare il contenuto della directory [$DIR_DIST]"
		return 1
	fi
	
	DIR_IVY_CACHE="$DIR_IVY/cache"
	echolog "eliminazione del contenuto della directory [$DIR_IVY_CACHE]"
	
	if ! [ -d "$DIR_IVY_CACHE" ]
	then
		echolog "la directory [$DIR_IVY_CACHE] non esiste"
		return 1
	fi
	
	rm -rf $DIR_IVY_CACHE/*
	if [ $? -ne 0 ]
	then
		echolog "impossibile eliminare il contenuto della directory [$DIR_IVY_CACHE]"
		return 1
	fi
	
	echolog "eliminazione dei vecchi file di log"
	
	for logfile in `ls "$DIR_LOG"`
	do
		if ! [ "$DIR_LOG/$logfile" = "$FILE_LOG" ]
		then
			echolog "eliminazione file [$DIR_LOG/$logfile]"
			rm -f "$DIR_LOG/$logfile"
			if [ $? -ne 0 ]
			then
				echolog "impossibile eliminare il file [$DIR_LOG/$logfile]"
				return 1
			fi
		fi
	done
}


builder_dist()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	revision=$2
	
	if [ -z "$2" ]
	then
		revision="head"
	fi
	
	progetto=$1
	
	
	if ! grep "^$progetto" "$FILE_PROGETTI" > /dev/null
	then
		echolog "il progetto [$progetto] non esiste"
		return 1
	fi
	
	URL_REPO=`grep "^$progetto[\s\t]*" "$FILE_PROGETTI" | head -n1 | awk '{print $2}'`
	
	if ! [ -d "$DIR_REPO/$progetto" ]
	then	
		echolog "checkout repository [$URL_REPO] alla revision [$revision]"
		$DIR_BIN/svnwrapper.sh get "$DIR_REPO/$progetto" $URL_REPO@$revision
		if [ $? -ne 0 ]
		then
			echolog "checkout fallito: repository [$URL_REPO], revision [$revision]"
			echolog "rimuovere eventualmente la directory del progetto con [rm -rf $DIR_REPO/$progetto]"
			return 1
		fi
	else
		echolog "update progetto [$progetto] con url [$URL_REPO] alla revision [$revision]"
		cd "$DIR_REPO/$progetto"
		$DIR_BIN/svnwrapper.sh get "$DIR_REPO/$progetto" $revision
		if [ $? -ne 0 ]; then echolog "update fallito: progetto [$progetto], repository [$URL_REPO], revision [$revision]"; return 1; fi
	fi
	
	vcsrevision=`$DIR_BIN/svnwrapper.sh rev "$DIR_REPO/$progetto"`
	$DIR_BIN/antwrapper.sh "$DIR_REPO/$progetto" "dist" "$vcsrevision"
	if [ $? -ne 0 ]; then echolog "build fallito: progetto [$progetto], repository [$URL_REPO], revision [$revision]"; return 1; fi
	
	if ! [ -z "$3" ]
	then
		OUTPUT=`builder_getlastbuild`
		echolog "esecuzione copia di [$OUTPUT] in [$3]"
		cp "$OUTPUT" "$3"
	fi
	
	return 0
}

builder_publibs()
{
	LIBS=`cat $FILE_PROGETTI | grep ^lib | awk '{print $1}'`

	for lib in $LIBS
	do
		echolog "publishing [$lib]..."
		DIR_LIB_REPO="$DIR_BASE/repo/$lib"
		
		REVISION_O_URL="head"
		
		if ! [ -d "$DIR_LIB_REPO" ]
		then
			REVISION_O_URL=`cat "$FILE_PROGETTI" | grep ^$lib | awk '{print $2}'`
		fi
		
		$DIR_BIN/svnwrapper.sh get $DIR_LIB_REPO $REVISION_O_URL 2>&1 > /dev/null
		$DIR_BIN/antwrapper.sh $DIR_LIB_REPO publish 2>&1 > /dev/null
		if [ $? -eq 0 ]
		then
			echolog "[$lib] pubblicata"
		else
			echolog "[$lib] ERRORE: eseguire [$0 build $lib] per verificare la build"
		fi
	done
}

builder_check_pidfile()
{
	if [ -f "$FILE_PID" ]
	then
		PID=`cat $FILE_PID`
		if ps -p $PID > /dev/null
		then
			echolog "processo gia' in esecuzione con pid [$PID]"
			exit 2
		fi
	fi
	
	echo $$ > "$FILE_PID"
}

builder_get_rev()
{
	if [ -z "$1" ]
	then
		helpmsg
		return 1
	fi
	
	revision=$2
	
	if [ -z "$2" ]
	then
		revision="head"
	fi
	
	progetto=$1
	
	
	if ! grep "^$progetto" "$FILE_PROGETTI" > /dev/null
	then
		echolog "il progetto [$progetto] non esiste"
		return 1
	fi
	
	if ! [ -d "$DIR_REPO/$progetto" ]
	then
		echolog ""
	fi
	
	revision=`$DIR_BIN/svnwrapper.sh rev "$DIR_REPO/$progetto"`
	
	echo $revision
}

builder_remove_pidfile()
{
	if [ -f "$FILE_PID" ]; then	rm -f "$FILE_PID"; fi
}

# ---------------------------------------------------------
# exec
# ---------------------------------------------------------

if [ "$1" = "auto" ]
then
	builder_check_pidfile
	
	builder_publibs

	if [ ! -z "$DIR_DIST_AUTO" ] && [ -d "$DIR_DIST_AUTO" ]
	then
		rm -fr "$DIR_DIST_AUTO"
	fi
	
	mkdir "$DIR_DIST_AUTO"
	
	echo ""
	
	for progetto in `cat "$FILE_PROGETTI" | grep -v ^lib | awk '{print $1}'`
	do
		echolog "building [$progetto]"
		builder_dist "$progetto" head "$DIR_DIST_AUTO/" 2>&1 > /dev/null
		if [ $? -eq 0 ]
		then
			PATH_DIST=`builder_getlastbuild`
			echolog "[$progetto] compilato"
		else
			echolog "[$progetto] ERRORE: controllare l'output di [$0 build $progetto]"
		fi
	done
	
	builder_remove_pidfile
	exit 0
fi

if [ "$1" = "dist" ]
then
	#builder_check_pidfile

	shift
	builder_dist $1 $2 $3
	RET=$?
	if [ $RET -eq 0 ]
	then
		echo ""
		builder_getlastbuild
		echo ""
	fi
	
	builder_remove_pidfile
	exit $RET
fi

if [ "$1" = "pub" ]
then
	builder_check_pidfile
	
	builder_publibs
	
	builder_remove_pidfile
	exit 0
fi

if [ "$1" = "ls" ]
then
	echo ""
	echolog "progetti disponibili:"
	echo ""
	cat "$FILE_PROGETTI"
	echo ""
	
	
	builder_remove_pidfile
	exit 0
fi

if [ "$1" = "clean" ]
then
	builder_check_pidfile
	
	builder_clean
	RET=$?
	
	builder_remove_pidfile
	exit $RET
fi

if [ "$1" = "last" ]
then
	builder_getlastbuild
	RET=$?
	
	builder_remove_pidfile
	exit $RET
fi

if [ "$1" = "rev" ]
then
	builder_check_pidfile
	
	shift
	builder_get_rev $@
	RET=$?
	
	builder_remove_pidfile
	exit $RET
fi

if [ "$1" = "svn" ]
then
	builder_check_pidfile

	shift
	$DIR_BIN/svnwrapper.sh $@
	RET=$?
	
	builder_remove_pidfile
	exit $RET
fi

if [ "$1" = "ant" ]
then
	builder_check_pidfile
	
	shift
	$DIR_BIN/antwrapper.sh $@
	RET=$?
	
	builder_remove_pidfile
	exit $RET
fi


helpmsg

builder_remove_pidfile
exit 0