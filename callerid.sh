#!/bin/sh
# Updated: 10/08/2006 by Brad House (brad <at> monetra <dot> com)
# Updated: 5/04/2007 by Ethan Burnside & Brian Barrett at the 
#     National Cristina Foundation (burnside <at> cristina <dot> org)
#     Added MySQL support.
#
# ./callerid_shell.agi "phonenum" "lookup order" "manual name"
#
# Requires: CURL (http://curl.haxx.se/)
#           SQLite3 [Only required if using database cache] 
#                   (http://www.sqlite.org)
#           MySQL [Only required if using database cache] 
#                   (http://www.mysql.org)
#
# MySQL Table Structure
#
# CREATE TABLE `callerid` (
#  `id` int(11) NOT NULL auto_increment,
#  `areacode` int(11) NOT NULL,
#  `phonenum` int(11) NOT NULL,
#  `calleridname` varchar(50) NOT NULL,
#  `origin` varchar(50) NOT NULL,
#  `ts` bigint(20) NOT NULL,
#  `perm` tinyint(4) NOT NULL,
#  PRIMARY KEY  (`id`),
#  KEY `area-phone` (`areacode`,`phonenum`)
# );
#
# Additional MySQL Feature - set "perm" column to 1 to keep entry from
#    being purged.  
#
#
# Script should be installed to /var/lib/asterisk/agi-bin/
#
# If using extensions.conf, call like:
#		exten => s,1,AGI(callerid_shell.agi|${CALLERIDNUM})
#		exten => s,2,NoOp(AGI Returned ${lookupname})
#		exten => s,3,Set(CALLERID(name)=${lookupname})
# 
# If using extensions.ael (AEL), call like:
#		AGI(callerid_shell.agi|${CALLERIDNUM});
#		NoOp(AGI Returned ${lookupname});
#		Set(CALLERID(name)=${lookupname});
#
#
# Lookup order may contain a space separated list of:
#    google  - google.com lookup (fastest)
#    411     - 411.com lookup (moderate speed)
#    anywho  - anywho.com lookup (slowest)
#    sqlite3 - Cached Database
#    mysql   - Cached Database
#    nanpa   - look up from database of NPA-NXX codes to find
#		city and state of caller, can obtain latest
#		list from: http://www.nanpa.com/reports/reports_cocodes_assign.html
#		Just unzip the 'all states' version and point the nanpa_db
#		variable below...
#  You may also specify the special 'manual' key and the
#  3rd arg 'manual name' in order to simply insert a static
#  entry into the database cache.
#
# Example:
#    ./callerid_shell.agi 555-555-1212 "manual" "John Doe"
#        - Will add entry into database cache as non-expiring
#          for phone number 555 5551212 ...
#    ./callerid_shell.agi 555-555-1212
#        - Will set variable 'lookupname' when it is done scanning
#          the default 'lookup_order'

# --------- SET THESE VARIABLES ---------

# Order to follow to lookup callerid
#  if using cache, sqlite3 should always be first,
#  nanpa is typically last.  Space separated list.
#  (warning, anywho is slow, recommended not to use them)
lookup_order="mysql google 411 anywho"

# Whether or not we want to auto-cache successful lookups
#
# 0 = off
# 1 = sqllite
# 2 = mysql
#
cache_lookups=2

# Whether or not to cache nanpa lookups 
# (if enabled, must also have cache_lookups enabled)
cache_nanpa=1

# Expiration timeframe in seconds for cached lookups
cache_expire=7776000  # 90 days

# SQLite database location (full path)
sqlite3db="/var/lib/asterisk/agi-bin/callerid_sqlite3.db"  

# SQLite command
sqlitecmd="sqlite3" 

#
# MySQL Variables
#
mysqlcmd="/usr/bin/mysql"
mysqlhost="localhost"
mysqluser="jgilmore"
mysqlpass="1ikhsw"
mysqldb="asterisk"
mysqltable="callerid"

# Location of downloaded NANPA db/txt ...
#  (download all states list from:
#    http://www.nanpa.com/reports/reports_cocodes_assign.html
#   and uncompress)
nanpa_db="/var/lib/asterisk/agi-bin/nanpa.txt"


# --------------------- SCRIPT BELOW ------------------------

replace_escaped_chars() {
	data="$*"
	data=`echo ${data} | sed -e 's/+/ /g'`
	data=`echo ${data} | sed -e 's/%20/ /g'`
	data=`echo ${data} | sed -e 's/%26/\&/g'`
	echo "${data}"
}

get_rawnumber() {
	mynum="${1}"
	mynum=`echo "${mynum}" | sed -e 's/+1//g' | sed -e 's/ //g' | sed -e 's/-//g' | sed -e 's/(//g' | sed -e 's/)//g'`
	firstnum=`echo "${mynum}" | head -c 1 -`
	if [ "${firstnum}" = "1" ] ; then
		mynum=`echo "${mynum}" | sed -e 's/1//'`
	fi
	echo "${mynum}"
}

get_areacode() {
	mynum=`get_rawnumber "${1}" | head -c 3 -`
	echo "${mynum}"
}

get_phonenum() {
	areacode=`get_areacode "${1}"`
	mynum=`get_rawnumber "${1}" | sed -e "s/${areacode}//"`
	echo "${mynum}"
}

get_nxx() {
	mynum=`get_phonenum "${1}" | head -c 3 -`
	echo "${mynum}"
}

lookup_411() {
	out=""
	fname=""
	lname=""
	myname=""
	out=`/usr/bin/curl -s -m 2 -A Mozilla/4.0 http://www.411.com/10668/search/Reverse_Phone?phone=${1}`
	fname=`echo ${out} | grep 'fname=' | sed -e 's/.*fname=//g' | cut -d\& -f1`
	if [ "${fname}" != "" ] ; then
		lname=`echo ${out} | grep 'lname=' | sed -e 's/.*lname=//g' | cut -d\& -f1`
		if [ "${lname}" != "" ] ; then
			lname=`replace_escaped_chars ${lname}`
			fname=`replace_escaped_chars ${fname}`
			myname="${fname} ${lname}"
		fi
	fi
	if [ "${myname}" = "" ] ; then
		company=`echo ${out} | grep 'company=' | sed -e 's/.*company=//g' | cut -d\& -f1`
		if [ "${company}" != "" ] ; then
			myname=`replace_escaped_chars ${company}`
		fi
	fi

	if [ "${myname}" != "" ] ; then
		echo "${myname}"
	fi
}

lookup_google() {
	data=""
	myname=""

	data=`/usr/bin/curl -s -m 2 -A Mozilla/4.0 http://www.google.com/search?q=phonebook:${1}`
	myname=`echo ${data} | grep Results | sed -e 's/.*Results//g' | sed -e 's:.*<font size=-2><br></font><font size=-1>::g' | sed -e 's:<.*::g' | cut -d- -f1`
	if [ "${myname}" = "" -o "${myname}" = " " ] ; then
		# Layout change, let's try catching this one.
		myname=`echo ${data} | grep Results | sed -e 's/.*Results//g' | sed -e 's:.*<font size=-2><br></font>::g' | sed -e 's:.*9><td>::' | sed -e 's:<.*::g' | cut -d- -f1`
	fi

	if [ "${myname}" != "" ] ; then
		echo "${myname}"
	fi
}

lookup_anywho() {
	data=""
	fname=""
	lname=""
	myname=""

	areacode=`get_areacode ${1}`
	phonenum=`get_phonenum ${1}`
	url="http://www.anywho.com/qry/wp_rl?npa=${areacode}&telephone=${phonenum}&btnsubmit=Search"
	data=`/usr/bin/curl -s -m 2 -A Mozilla/4.0 "$url" | grep 'urlgen.rmservers.com'`
	fname=`echo ${data} | sed -e 's/.*firstname=//g' | cut -d\& -f1`
	lname=`echo ${data} | sed -e 's/.*lastname=//g' | cut -d\& -f1`
	if [ "${fname}" != "" -a "${lname}" != "" ] ; then
		fname=`replace_escaped_chars ${fname}`
		lname=`replace_escaped_chars ${lname}`
		myname="${lname}, ${fname}"
	fi

	if [ "${myname}" != "" ] ; then
		echo "${myname}"
	fi
}

lookup_mysql() {
	if [ ${cache_lookups} != "2" ] ; then
		return 1
	fi
	areacode=`get_areacode ${1}`
	phonenum=`get_phonenum ${1}`

	if [ "${areacode}" = "" -o "${phonenum}" = "" ] ; then
		return 1
	fi

	curr_ts=`date +%s` # Current unix timestamp
	myname=""

	data=`${mysqlcmd} -h ${mysqlhost} -u ${mysqluser} -p${mysqlpass} -e "SELECT calleridname,ts FROM ${mysqltable} WHERE areacode=${areacode} AND phonenum=${phonenum}\\G" ${mysqldb}`

	if [ "$?" != "0" -o "${data}" = "" ] ; then
		return 1
	fi

	while read x ; do
 		ts=`echo "${x}" | grep ts | awk '{ print $2 }'`
 		sql_name=`echo "${x}" | grep calleridname | sed -e 's,calleridname:\ \(.*\)$,\1,g'`

		[ "$ts" = "" ] && ts=0 
		[ "$curr_ts" = "" ] && curr_ts=0 

		mydiff=`expr "${curr_ts}" - "${ts}"`
		[ "$mydiff" = "" ] && mydiff=0 

		if [ "${ts}" != "0" -a "${mydiff}" -gt "${cache_expire}" ] ; then
			${mysqlcmd} -h ${mysqlhost} -u ${mysqluser} -p${mysqlpass} -e "DELETE FROM ${mysqltable} WHERE perm=0 AND areacode=${areacode} AND phonenum=${phonenum} AND ts=${ts};" ${mysqldb}
		fi

		if [ "${sql_name}" != "" ] ; then
			myname=${sql_name}
		fi
	done <<< "`echo "${data}"`"

	if [ "${myname}" != "" ] ; then
		echo "${myname}"
	fi
}

lookup_nanpa() {
	areacode=`get_areacode "${1}"`
	phonenum=`get_phonenum "${1}"`
	nxx=`get_nxx "${1}"`	
	line=`grep "${areacode}-${nxx}" "${nanpa_db}"`
	STATE=`echo "${line}" | cut -b 1-3 | sed 's/^[ ^t\x09]*//' | sed 's/[ ^t\x09]*$//'`
	RATECENTER=`echo "${line}" | cut -b 79-90 | sed 's/^[ ^t\x09]*//' | sed 's/[ ^t\x09]*$//'`
	if [ "${STATE}" != "" -a "${RATECENTER}" != "" ] ; then
		echo "${RATECENTER}, ${STATE}"
	fi
}


insert_mysql() {
	areacode=`get_areacode "${1}"`
	phonenum=`get_phonenum "${1}"`
	myname="${2}"
	mywho="${3}"

	if [ "${areacode}" = "" -o "${phonenum}" = "" -o "${myname}" = "" ] ; then
		return 1
	fi

	# Clear any previous entry that may exist
	${mysqlcmd} -h ${mysqlhost} -u ${mysqluser} -p${mysqlpass} -e "DELETE FROM ${mysqltable} WHERE areacode=${areacode} AND phonenum=${phonenum};" ${mysqldb} > /dev/null 2>&1

	if [ "${mywho}" = "manual" ] ; then
		curr_ts=0; # Non-expiring if manual
		perm=1
	else
		curr_ts=`date +%s`
		perm=0
	fi

	${mysqlcmd} -h ${mysqlhost} -u ${mysqluser} -p${mysqlpass} -e "INSERT INTO ${mysqltable} (areacode, phonenum, ts, calleridname, origin, perm) VALUES (${areacode}, ${phonenum}, ${curr_ts}, '${myname}', '${mywho}', '${perm}');" ${mysqldb}

	if [ "$?" != "0" ] ; then
		return 1
	fi
	return 0	
}

lookup_name() {
	for x in ${1} ; do
		lu_name=""
		#echo "lookup via ${x}" 1>&2
		case ${x} in
			mysql)
				lu_name=`lookup_mysql "${2}"`
			;;
			411)
				lu_name=`lookup_411 "${2}"`
			;;
			google)
				lu_name=`lookup_google "${2}"`
			;;
			anywho)
				lu_name=`lookup_anywho "${2}"`
			;;
			nanpa)
				lu_name=`lookup_nanpa "${2}"`
			;;
			manual)
				lu_name="${3}"
			;;
		esac
		if [ "${lu_name}" != "" ] ; then
			if [ "${x}" != "sqlite3" -a "${cache_lookups}" = "1" ] ; then
				if [ "${x}" != "nanpa" -o "${cache_nanpa}" = "1" ] ; then
					insert_sqlite3 "${2}" "${lu_name}" "$x"
				fi
			fi

			if [ "${x}" != "mysql" -a "${cache_lookups}" = "2" ] ; then
				if [ "${x}" != "nanpa" -o "${cache_nanpa}" = "1" ] ; then
					insert_mysql "${2}" "${lu_name}" "$x"
				fi
			fi

			echo "${lu_name}"
			return 0
		fi 
	done
	return 0
}

if [ "$#" -lt "1" ] ; then
	echo "Usage: $0 <phonenum> <lookup order> <manual name>"
	echo ""
	echo "Phone Num  : phone number to look up"
	echo "Lookup List: 411 google anywho nanpa sqlite3"
	echo "    default: ${lookup_order}"
	echo "Manual Name: Enter if you want to add an entry to the sqlite3 cache"
	echo ""
	exit 1
fi

name=""
if [ "${1}" != "" ] ; then
	if [ "${2}" != "" ] ; then
		lookup_order="${2}"
	fi
	name=`lookup_name "${lookup_order}" "${1}" "${3}"`
fi
	
# Truncate to 18 characters max
#if [ "${name}" != "" ] ; then
#	name=`echo ${name} | head -c 18 -`
#fi

#echo "SET VARIABLE lookupname \"${name}\""
echo ${name}
