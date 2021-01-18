#!/bin/sh

################################################################################
# 
# slwi.sh - itflabtijtslwi interpreter
# 
# Written in 2021 by TpaeFawzen (https://github.com/GH-TpaeFawzen)
# 
# To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
# 
# You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
# 
# 
# slwi.sh -- itflabtijtslwi interpreter
# 
# - !!!! (exit status setting failing)
# - debug: s/echo/printf %s/ to avoid escape sequence
# - debug?: now -d is treated as -d2 by default!
# - made VERSIONING (these on this script!) actual comment
# - LICENSE above
# 
# written by GH-TpaeFawzen on 2021/01/18 17:36
# (The time above is in JST)
# 
################################################################################

set -eu # exit on error and undefined variable
umask 0022
export LC_ALL=C # locale has to be default
type getconf >/dev/null 2>&1 &&
type command >/dev/null 2>&1 &&
export PATH="$(command -p getconf PATH)${PATH+:}${PATH-}"
export UNIX_STD=2003 # for HP-UX

usagex(){
	cat <<-USAGE
	Usage: ${0##*/} [-d[1|2]] [--shut-up] [FILE]
	Option:
	  -d: debug mode; outputs the program when below, to STDERR.
	      (default: -d2)
	    -d1: whenever program itself produce an output.
	    -d2: before each step.
	  --shut-up: (works only if input for program is from terminal)
	             Do not notify when itflabtijtslwi program ends.
	Argument:
	  FILE: itflabtijtslwi program source file.
	Note:
	  FILE can be omitted, or one of the following values:
	    -
	    /dev/stdin
	    /dev/fd/0
	    /proc/self/fd/0
	  to let the program be read from STDIN.
	  FILE may begin with hyphen.
	USAGE
	exit 1
}
errorx(){
	printf '%s\n' "${0##*/}: ${2:?Missing error message}" 1>&2
	exit "${1:?Missing exit code}"
}

# help?
case "${1-}" in ('-?'|'-h'|'--help'|'--usage')
	usagex
;;esac

# debug mode?
debug=0
case "${1-}" in ('-d')
	debug=2
	shift
;;('-d'[12])
	debug=${1#-d}
	shift
;;esac

# shutup mode?
shutup=0
case "${1-}" in (--shut-up)
	shutup=1
	shift 1
;;esac

# look for itflabtijtslwi source file.
case "${1-}" in (''|'-'|'/dev/stdin'|'/dev/fd/0'|'/proc/self/fd/0')
	set --
;;(*)
	{
		test -f "$1" ||
		test -c "$1" ||
		test -p "$1"
	} && {
		test -r "$1" ||
		errorx 31 "$1: Cannot read the file"
	} || {
		errorx 31 \
		"$1: Not a regular file/character special/fifo"
	}
;;esac

# make sure a file whose name begin with hyphen should be
# parsed correctly
case "${1-}" in (''|'/'*|'./'*|'../'*)
	:
;;(*)
	set -- "./$1"
;;esac

# constants below
readonly slashO=$( printf /    | od -A n -t o1 -v | tr -Cd 01234567 )
readonly bslshO=$( printf \\\\ | od -A n -t o1 -v | tr -Cd 01234567 )
readonly gO=$(     printf G    | od -A n -t o1 -v | tr -Cd 01234567 )
readonly LFO=$(    printf \\n  | od -A n -t o1 -v | tr -Cd 01234567 )

PROGRAM_FROM=argument
case "$#" in (0) PROGRAM_FROM=stdin;; esac

INPUT_SOURCE=piped
test -t 0 && INPUT_SOURCE=tty

readonly PROGRAM_FROM INPUT_SOURCE

code=0

# main process below
{
	# read program (with ONE LINE)
	cat ${1:+"$1"} |
	od -A n -t o1 -v |
	tr -Cd 01234567\\n |
	sed 's/.../XX&/g' |
	tr -d \\012
	echo
	# no more program

	LF="$(printf \\\\n_)";LF="${LF%_}"
	
	# read input (ONE BYTE PER LINE)
	case "$INPUT_SOURCE" in (piped)
		cat |
		od -A n -t o1 -v |
		tr -Cd 01234567\\n |
		sed 's/.../XX&'"$LF"'/g' |
		grep .
	;;(tty)
		while :; do
			l=$(
			head -n 1 |
			od -A n -t o1 -v |
			tr -Cd 01234567)
			echo "$l" |
			sed 's/.../XX&'"$LF"'/g'
			case "$l" in (*"$LFO") : ;;(*) break ;;esac
		done
	;;esac
	# no more input
} | {
# itflabtijtslwi interpreter
awk -v s="XX${slashO}" \
    -v b="XX${bslshO}" \
    -v gg="XX${gO}XX${gO}" \
    -v LF="XX$(printf \\n | od -A n -t o1 -v | tr -Cd 01234567)" \
    -v bufmax="$(getconf ARG_MAX 2>&1 || :)" \
'function bprint(str){
	# buffering and printing
	if(buflen+length(str)>=bufmax){
		print buf;
		buf=str;
		buflen=length(str);
		return;
	}
	buf=buf str;
	# TODO: maybe not necessary for many of short lines;
	# TODO: I think it good when long line.
#	if(str==LF){
#		print buf;
#		buf="";
#		buflen=0;
#		return;
#	}
	buflen=length(str);
}
function bflush(){
	if(buf=="")return;
	print buf;
	buf="";
	buflen=0;
}
BEGIN{
	if(bufmax==""){ bufmax=4096; }
	else          { bufmax/=2  ; }
	bufmax -= length("printf ");
	buf     = "";
	buflen  = 0;

	# make sure that printf never say "missing operand"
	print "\"\"";

	# read program
	getline program;
	
	# now process program
	mode      = "quine"; # or "pattern" or "replace" or "ipattern"
	pattern   = "";
	replace   = "";
	ipattern  = "";
	eoi       = "notyet"; # or "reached"

	for(;;){
		'"$(case "$debug" in (2)
			printf %s 'printf "[%s]\n",program >"/dev/stderr";'
		;;esac)"'

		if(program==""){
			break;
		}
		if(program==b||program==s){
			break;
		}

		# XX\\\XX... XX...
		# 1234567890 12345
		if(mode=="quine"   &&program~("^" b "XX...")){
			bprint(substr(program,6,5));
			program=substr(program,11);
			'"$(case "$debug" in (1)
				printf %s 'printf "[%s]\n",program >"/dev/stderr";'
			;;esac)"'
		}
		else if(mode=="pattern" &&program~("^" b "XX...")){
			pattern=pattern substr(program,6,5);
			program=substr(program,11);
		}
		else if(mode=="replace" &&program~("^" b "XX...")){
			replace=replace substr(program,6,5);
			program=substr(program,11);
		}
		else if(mode=="ipattern"&&program~("^" b "XX...")){
			ipattern=ipattern substr(program,6,5);
			program=substr(program,11);
		}

		# XX/// XX...
		# 12345 67890
		else if(mode=="quine"   &&program~("^" s)){
			program=substr(program,6);
			mode="pattern";
		}
		else if(mode=="pattern" &&program~("^" s)){
			program=substr(program,6);
			mode="replace";
		}
		else if(mode=="replace" &&program~("^" s)){
			while(pattern==""){
				# get trapped here
			}
			program=substr(program,6);
			while(program~pattern){
				sub(pattern,replace,program);
			}
			pattern=""; # make sure to
			replace=""; # reset these
			mode="quine";
		}
		# JUST SKIP HERE!
		# else if(mode=="ipattern"&&program~("^" s)){
		# 	ipattern=ipattern substr(program,1,5);
		# 	program=substr(program,6);
		# }

		# XXGGGXXGGG XX...
		# 1234567890 12345
		else if(mode=="quine"   &&program~("^" gg)){
			program=substr(program,11);
			mode="ipattern";
		}
		# JUST SKIP HERE!
		# else if(mode=="pattern" &&program~("^" gg)){
		# 	pattern=pattern substr(program,1,10);
		# 	program=substr(program,11);
		# }
		# else if(mode=="replace" &&program~("^" gg)){
		# 	replace=replace substr(program,1,10);
		# 	program=substr(program,11);
		# }
		else if(mode=="ipattern"&&program~("^" gg)){
			if(eoi=="notyet"){
				bflush();
				if((glstatus=getline)>0)
					replace=$0;
				if(glstatus<0)
					printf"%s%s\n",
					"Warning: Input error detected; "\
					"treating as EOF" >"/dev/stderr"
				eoi="reached"
			}
			# almost copied and yanked here as above
			while(ipattern==""){
				# get trapped here
			}
			program=substr(program,11);
			while(program~ipattern){
				sub(ipattern,replace,program);
			}
			ipattern=""; # make sure to
			replace=""; # reset these
			mode="quine";
		}
		# normal characters only
		else if(mode=="quine"   ){
			bprint(substr(program,1,5));
			program=substr(program,6);
			'"$(case "$debug" in (1) 
				printf %s 'printf "[%s]\n",program >"/dev/stderr";'
			;;esac)"'
		}
		else if(mode=="pattern" ){
			pattern=pattern substr(program,1,5);
			program=substr(program,6);
		}
		else if(mode=="replace" ){
			replace=replace substr(program,1,5);
			program=substr(program,6);
		}
		else if(mode=="ipattern"){
			ipattern=ipattern substr(program,1,5);
			program=substr(program,6);
		}
		else{
			# IMPOSSIBLE!
			print "Error: HOW!?" >"/dev/stderr";
			exit 66;
		}
	}

	bflush();
	'"$(case "$shutup$INPUT_SOURCE" in (0tty)
		echo \
		'print"Info: itflabtijtslwi program ended successfully." '\
		'>"/dev/stderr"'
	;;esac)"'

	exit 0;
}' && :
	# FIXME any better ideas?
	code="$?"
}|
tr X \\\\ |
xargs -n 1 printf

# finally
exit "$code"
