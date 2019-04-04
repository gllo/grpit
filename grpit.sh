#!/bin/bash
#################################################################################
#Group files according to a predefined size limit to ease burning media. 
#Written by gllo, April 2008
#Copyright (C) 2008-2019 GLATT Lőrinc (gllo)
#E-mail: lorinc.glatt@gmail.com
#
#This program is free software: you can redistribute it and/or modify it
#under the terms of the GNU General Public License as published by the Free
#Software Foundation, either version 3 of the License, or any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY
#WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
#PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with
#this program. If not, see <https://www.gnu.org/licenses/>.
#################################################################################
prog_name=$(basename $0)

usage()
{
echo -e "Group files according to a predefined size limit to ease burning media. 

USAGE:
$prog_name [[-a algorithm] [-d directory] [-gid group id] [-gl group limit] [-h]]

OPTIONS:
-a | --algorithm
    Currently two algorithms are supported:

	linear
			When the next unit (file/dir) to be grouped does not
			fit in group, a new group is started with this unit as
			the first element. Noob method.

	linear_ext
			This is the default. When the next unit to be grouped
			does not fit in group, the remaining units will be
			examined if any of them fits. A new group will be
			started when none of the examined units fit in group.

	E.g.:
		$prog_name -d ~/movies/ -gl dvd-r-dl -a linear

-d | --directory
	Default is the current directory. $prog_name will not recurse
	into the subdirectories of the directories of the specified directory.

-gid | --group-id 
    The default output format (when no group id is given) is the detailed view
    of all groups created. Select a group by remembering its id and run the
    script again with the -gid option set. Now the output format will be a
    simple list of directories. Redirect output to a file so later you can
    provide that to mkisofs/growisofs.  

	E.g.: 	$prog_name -d ~/movies/ -gid 3 > pathlist.txt
		growisofs -dry-run -Z /dev/dvd -R -J -path-list pathlist.txt

-gl | --group-limit
    The group limit has to be provided in bytes or by a corresponding keyword
    instead: 
	
		cd-r	   (737.280.000 bytes)
		dvd-r-sl (4.707.319.808 bytes) [default]
		dvd+r-sl (4.700.372.992 bytes)
		dvd-r-dl (8.543.666.176 bytes)
		dvd+r-dl (8.547.991.552 bytes)

	E.g.:
		$prog_name -d ~/movies/ -gl dvd+r-sl
		$prog_name -d ~/movies/ -gl 1460288880

    If the size of a grouped unit exceeds the group limit, it will be simply
    left out from grouping. Be careful when specifying limits - defining
    improper sizes for media will also lead to improper groupings.

-h | --help
	List this help.
"
}

cdr=737280000 
dms=4707319808
dps=4700372992
dmd=8543666176
dpd=8547991552

dir=.
glimit=$dms
algorithm="linear_ext"
gid=

while [ "$1" != "" ]; do
	case $1 in		
		-a | --algorithm)
				shift
				case $1 in
					linear|linear_ext)	
						algorithm=$1
						;;
					*)
						usage
						exit 1
				esac
				;;
		-d | --dir)	shift
				dir=$1
				;;
		-h | --help)	usage
				exit
				;;
		-gl | --group-limit)	
				shift
				case $1 in
					cd-r)	
						glimit=${cdr}
						;;
					dvd-r-sl)
						glimit=${dms}
						;;
					dvd+r-sl)
						glimit=${dps}
						;;
					dvd-r-dl)
						glimit=${dmd}
						;;
					dvd+r-dl)
						glimit=${dpd}
						;;
					*[!0-9]*|"")
						usage 
						exit 1
						;;
					*)
						glimit=$1
				esac
				;;
		-gid | --group-id)
				shift
				case $1 in
					*[!0-9]*|"")
						usage
						exit 1
						;;
					*)
						gid=$1
				esac
				;;
		*)		usage
				exit 1
	esac
	shift
done

list=`du -b -a --max-depth=1 $dir`

echo "$list" | awk -v gid=${gid} -v glimit=${glimit} -v algorithm=${algorithm} '
	BEGIN\
	{
		FS = "\t"
		gsum = 0
		gcounter = 1
	} 

	{sizes[NR] = $1; paths[NR] = $2}

	END\
	{
		if (algorithm == "linear_ext")
		{
			for (j = 1; j < FNR; j++) 
				status[j] = 0
			linear_ext()
		}
		if (algorithm == "linear")
			linear()
	}
	
	function linear_ext()
	{
		for (k = 1; k < FNR; k++)
		{
			if (sizes[k] > glimit)
			{
				status[k] = 2
				continue
			}
			else
			{
				if (status[k] != 0)
					continue

				if (gsum == 0 && gid == "")
					grp_header(gcounter)

				for (l = 1; l < FNR; l++)
				{
					if (status[l] != 0)
						continue

					if (gsum + sizes[l] > glimit)
						continue
					else
					{
						gsum += sizes[l]
						status[l] = 1
						if (gid == "")
							printf "%'"'"'17d \t %s \n", sizes[l], paths[l]
						if (gid == gcounter)
							printf "%s\n", paths[l]
						#break
					}
				}

				if (gid == "")
					summary(gsum, glimit);
				gsum = 0
				gcounter++
			}
		}
		if ((gid != "") && (!(gid < gcounter) || !(gid > 0)))
			printf "%s%d%s\n", "Group ", gid, " does not exist!"

	}

	function linear()
	{
		for (i = 1; i < FNR; i++)
		{
			if (sizes[i] > glimit)
				continue
			else 
			{
				if (gsum == 0 && gid == "")
					grp_header(gcounter)

				if (gsum + sizes[i] <= glimit) 
				{
					gsum += sizes[i]
					if (gid == "")
						printf "%'"'"'17d \t %s \n",  sizes[i], paths[i] 
					if (gid == gcounter)
						printf "%s\n", paths[i]
				}
				else 
				{
					if (gid == "")
						summary(gsum, glimit);
					gsum = 0
					gcounter++
					i-- 
				}
			}
		}
		if (gsum != 0 && gid == "")	
			summary(gsum, glimit);
		if ((gid != "") && (!(gid <= gcounter) || !(gid > 0)))
			printf "%s%d%s\n", "Group ", gid, " does not exist!"
	}

	function drawline(len)
	{
		for (j = 0; j < len; j++)
			printf "%s", "-"
		printf "\n"
	}

	function grp_header(gcounter)
	{
		drawline(80);
		printf "%s %d%s \n", "Group", gcounter, ":";
		drawline(80);
	}

	function summary(sum, limit) 
	{
		drawline(80);
		printf "%'"'"'17d \t %s\n", sum, "bytes total";
		printf "%'"'"'17d \t %s\n", limit, "bytes limit";
		printf "%'"'"'17d \t %s\n\n\n", limit-sum, "bytes remain";
	}
'
