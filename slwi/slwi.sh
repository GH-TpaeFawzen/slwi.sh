#!/bin/sh

:<<-'VERSION'

slwi.sh -- itflabtijtslwi interpreter

- TODO: why GG does not work?
- implemented -d1 debug

written by GH-TpaeFawzen on 2021/01/02 16:28 (JST)

VERSION

set -eu # exit on error and undefined variable
umask 0022
export LC_ALL=C # locale has to be default
type getconf >/dev/null 2>&1 &&
type command >/dev/null 2>&1 &&
export PATH="$(command -p getconf PATH)${PATH+:}${PATH-}"
export UNIX_STD=2003 # for HP-UX

usagex(){
	cat <<-'USAGE'
	Usage: ${0##*/} [-d[1|2]] [FILE]
	Option:
	  -d: debug mode; outputs the program when below, to STDERR.
	      (default: -d2)
	    -d1: whenever program itself produce an output.
	    -d2: before each step.
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

# debug mode?
debug=0
case "${1-}" in ('-d'|'-d'[12])
	set -- "${1#-d}" "$@"
	debug=${1:+2}
	shift 2
esac

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
		errorx 1 "$1: Cannot read the file"
	}
	test -d "$1" &&
		errorx 1 "$1: Is a directory"
esac

# make sure a file whose name begin with hyphen should be
# parsed correctly
case "${1-}" in (''|'/'*|'./'*|'../'*)
	:
;;(*)
	set -- "./$1"
esac

# constants
readonly slashO=$( printf /  | od -A n -t o1 -v | tr -Cd 01234567 )
readonly bslshO=$( printf \\ | od -A n -t o1 -v | tr -Cd 01234567 )
readonly gO=$(     printf G  | od -A n -t o1 -v | tr -Cd 01234567 )

# make temporary directory
mktd(){
readonly fnamec=$(
	tr -d \\012 <<-CHARS
	1234567890
	qwertyuiopasdfghjklzxcvbnm
	QWERTYUIOPASDFGHJKLZXCVBNM_
	CHARS
)
test -c /dev/urandom &&
	set -- $(
		strings /dev/urandom |
		tr -Cd "$fnamec" |
		dd bs=14 count=1 2>/dev/null
	) ||
	set -- $(
		(
			ps -Ao pid,etime,pcpu,vsz
			date
		) |
		# generate <=42 eight-digit decimals
		od -A n -t d4 -v |
		tr -Cs 0123456789 \\012 |
		grep [0-9] |
		tail -n 42 |
		sed 's,.*\(........\)$,\1,' |
		# generate filename randomly
		awk '
		BEGIN{a=-(2**31);}
		{a+=$0;}
		END{
			srand(a);
			c="'"$fnamec"'";
			L=length(c);
			l=14;
			for(i=1;i<=l;i++){
				j=int(rand()*L)+1;
				p=substr(c,j,1);
				printf p;
			}
		}'
	)
test -e "$1" &&
	errorx 2 \
		'Temporary directory could not be made; please try again'

#(umask 0177; touch "$1")
#(umask 0177; mkdir "$1")
(umask 0077; mkdir "$1")
printf %s\\n "$1"
}

# main process below
# もしもプログラムが標準入力でかつゼロ番へのリダイレクトがなければ二回EOFを読むまで
# 一方で標準入力でゼロ番へのリダイレクトがあればプログラムへの入力はなし
# あとはいいだろ?

# program: from STDIN
# program input: from terminal
if
	case "$#" in (0) test -t 0
	;;(*) false
	esac
then
	tmp="$(mktd)"
	# make sure to remove temporary directory
	trap "rm -rf $tmp" INT QUIT KILL ABRT
	
	# plscont="${tmp}/c.$$"
	# : >"$plscont"
	plsdie="${tmp}/d.$$"
	plsread="${tmp}/r.$$"

	{
		# read program
		od -A n -t o1 -v |
		tr -Cd 01234567\\012 |
		sed 's/.../&X/g' |
		tr -d \\012
		echo
		# no more program
		# echo EOP
		# read input on demand
		while :; do
			# test -e "$plscont" || break
			test -e "$plsdie" && break
			test -e "$plsread" || continue
			if IFS= read -r l; then
				# with LF
				printf %s\\n "$l" |
				od -A n -t o1 -v |
				tr -Cd 01234567\\012 |
				sed 's/.../&X/g' |
				tr -d \\012
				echo
				rm "$plsread"
			else
				# without LF
				printf %s "$l" | 
				od -A n -t o1 -v |
				tr -Cd 01234567\\012 |
				sed 's/.../&X/g' |
				tr -d \\012
				echo
				break # because reached to EOF
			fi
		done
		# no more input
	} |
	# itflabtijtslwi interpreter
	awk -v s="${slashO}X" \
	    -v b="${bslshO}X" \
	    -v gg="${gO}X${gO}X" \
	    -v plsread="$plsread" \
	    -v plsdie="$plsdie" \
	'BEGIN{
		# make sure that printf never say "missing operand"
		print "\"\"";

		# # read program
		# program="";
		# 	for(getline;$0!="EOP";getline)
		# program=program $0;

		# read program
		getline program;
		
		# now process program
		input     = "";
		eoi       = "notyet"; # or "reached"
		mode      = "quine"; # or "pattern" or "replace" or "ipattern"
		pattern   = "";
		replace   = "";
		ipattern  = "";
		for(;;){
			'"$(
			case "$debug" in (2) cat <<-'DEBUG2'
			printf "[%s]\n",program >"/dev/stderr";
			DEBUG2
			esac
			)"'

			if(program==""){
				break;
			}

			if(                  program==b            ){
				break;
			}
			if(mode=="quine"   &&program~("^" b "...X")){
				print substr(program,5,4);
				program=substr(program,9);
				'"$(
				case "$debug" in (1) cat <<-'DEBUG1'
				printf "[%s]\n",program >"/dev/stderr";
				DEBUG1
				esac
				)"'
			}
			if(mode=="pattern" &&program~("^" b "...X")){
				pattern=pattern substr(program,5,4);
				program=substr(program,9);
			}
			if(mode=="replace" &&program~("^" b "...X")){
				replace=replace substr(program,5,4);
				program=substr(program,9);
			}
			if(mode=="ipattern"&&program~("^" b "...X")){
				ipatern=ipattern substr(program,5,4);
				program=substr(program,9);
			}

			if(mode=="quine"  &&program~("^" s)){
				program=substr(program,5);
				mode="pattern";
			}
			if(mode=="pattern"&&program~("^" s)){
				program=substr(program,5);
				mode="replace";
			}
			if(mode=="replace"&&program~("^" s)){
				while(pattern==""){
					# get trapped here
				}
				program=substr(program,5);
				while(program~pattern){
					sub(pattern,replace,program);
				}
				pattern="";
				replace="";
				mode="quine";
			}

			if(mode=="quine"   &&program~("^" gg)){
				program=substr(program,9);
				mode="ipattern";
			}

			### XXX BELOW
			if(mode=="ipattern"&&program~("^" gg)&&eoi=="notyet" ){
				if(input==""){
					printf "">plsread;
					_=getline input;
					if(!_){
						eoi="reached";
						replace="";
					}
					if(_==-1){
						print "WTF WITH INPUT ERROR!"\
							>"/dev/stderr";
						exit 16;
					}
					if(_==1){
						replace=substr(input,1,4);
						input=substr(input,5);
					}
				}else{
					replace=substr(input,1,4);
					input=substr(input,5);
				}
				while(ipattern==""){
					# get trapped here
				}
				program=substr(program,9);
				while(program~ipattern){
					sub(ipattern,replace,program);
				}
				ipattern="";
				replace="";
				mode="quine";
			}
			if(mode=="ipattern"&&program~("^" gg)&&eoi=="reached"){
				while(ipattern==""){
					# get trapped here
				}
				program=substr(program,9);
				replace="";
				while(program~ipattern){
					sub(ipattern,replace,program);
				}
				ipattern="";
				mode="quine";
			}
			### XXX ABOVE

			if(mode=="quine"   &&program!~("^(" s "|" b "|" gg ")")){
				print substr(program,1,4);
				program=substr(program,5);
				'"$(
				case "$debug" in (1) cat <<-'DEBUG1'
				printf "[%s]\n",program >"/dev/stderr";
				DEBUG1
				esac
				)"'
			}
			if(mode=="pattern" &&program!~("^(" s "|" b        ")")){
				pattern=pattern substr(program,1,4);
				program=substr(program,5);
			}
			if(mode=="replace" &&program!~("^(" s "|" b        ")")){
				replace=replace substr(program,1,4);
				program=substr(program,5);
			}
			if(mode=="ireplace"&&program!~("^("       b "|" gg ")")){
				ireplace=ireplace substr(program,1,4);
				program=substr(program,5);
			}
		}

		printf"">plsdie;
	}' |
	sed 's/\(...\)X/\\\\\1/g' |
	xargs -n 1 printf

	# remove
	rm -rf "$tmp"
	trap - INT QUIT KILL ABRT
fi

exit $? #### AT THIS POINT!

# program: from STDIN
# program input: from elsewhere
case "$#" in 0)
	if ! test -t 0; then
	fi
esac

# program: from file
case "$#" in 1)

esac

# main process below
LF="$(printf \\012-)"; LF="${LF%-}"

cat ${1:-"$1"} |
od -A n -t o1 -v |
tr -Cd 01234567\\012 |
sed "s/.../&$LF/g" |
sed "s/$slashO/"'S/' |
sed "s/$bslshO/"'B/' |
tr -d \\012 >"$tmpf"

while test -s "$tmpf"; do
	grep -q -v '[SB]' "$tmpf" && {
		cat "$tmpf"
		break
	}
	grep -q -v ''
done

exit $?

:<<'whatever'
#!/usr/bin/perl -w
#By Oerjan Johansen, June 2009-Jan 2012.  This file is in the public domain.

my $debug =
    ($#ARGV >= 0 and $ARGV[0] =~ m/^-d([1-2]?)$/ and shift and ($1 || 2));
$| = 1;

$_ = join '', <>;
while (1) {
        print "\n[", $_, "]" if $debug >= 2;
        if (s!^GG((?:[^/\\]|\\.)*?)GG!!s) {
            my $s = $1;
            $s =~ s/\\(.)/$1/gs;
            $d = getc();
            no warnings;
            while (s/(?:\Q$s\E)/$d/) {
            }
        }
        elsif (s!^([^/\\][^/\\G]*)!! or s!^\\(.)!!s) {
                print($1);
                print "\n[", $_, "]" if $debug == 1;
        }
        elsif (s!^/((?:[^/\\]|\\.)*)/((?:[^/\\]|\\.)*)/!!s) {
            my ($s,$d) = ($1,$2);
            $s =~ s/\\(.)/$1/gs;
            $d =~ s/\\(.)/$1/gs;
            while (s/(?:\Q$s\E)/$d/) {
            }
        }
        else { last; }
}
whatever
