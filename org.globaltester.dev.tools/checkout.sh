#! /bin/bash
#
# Checkout all repos accessible with the given private key and build the product.
#

PATTERN='(\.releng|\.integrationtest|\.scripts)($|\/)'

#set default values

REPOSITORY=org.globaltester.demo
FOLDER=org.globaltester.demo.releng
DESTINATION=
SOURCE=GlobalTester

PARAMETER_NUMBER=0
FULL_CLONE=0
INTERACTIVE=1
IGNORE_EXISTING=0


while [ $# -gt 0 ]
do
	case "$1" in
		"-h"|"--help") echo -en "Usage:\n\n"
			echo -en "`basename $0` <options>\n\n"
			echo "-r  | --repo            sets the repository name for the build                 defaults to $REPOSITORY"
			echo "                         Setting this as the first parameter also sets folder"
			echo "                         to <value>.releng"
			echo "-f  | --folder          sets the project folder name for the build             defaults to $FOLDER"
			echo "-d  | --destination     sets the destination folder name for the checkout      defaults to $DESTINATION"
			echo "-p  | --pattern         the pattern inversely matched to exclude folder        defaults to $PATTERN"
			echo "-b  | --branch          the branch to be checked out"
			echo "-s  | --source          the source to be used                                  defaults to $SOURCE"
			echo "-i  | --ignore          ignores existing repository folders"
			echo "-fc | --full            clone all accessible repositories"
			echo "-ni | --non-interactive assume answers needed to proceed"
			echo "-h  | --help            display this help"
			exit 1
		;;
		"-p"|"--pattern")
			if [[ -z "$2" ]]
			then
				echo "Pattern is missing!"
				exit 1
			fi
			PATTERN=$2
			shift 2
		;;
		"-f"|"--folder")
			if [[ -z "$2" || $2 == "-"* ]]
			then
				echo "Folder parameter needs a folder to use!"
				exit 1
			fi
			FOLDER=$2
			shift 2
		;;
		"-r"|"--repo")
			if [[ -z "$2" || $2 == "-"* ]]
			then
				echo "Repository parameter needs a folder to use!"
				exit 1
			fi
			REPOSITORY=$2
			if [ $PARAMETER_NUMBER -eq 0 ]
			then
				FOLDER="$REPOSITORY.releng"
			fi
			shift 2
		;;
		"-d"|"--destination")
			if [[ -z "$2" || $2 == "-"* ]]
			then
				echo "Destination parameter needs a folder to use!"
				exit 1
			fi
			DESTINATION=$2
			shift 2
		;;
		"-b"|"--branch")
			if [[ -z "$2" || $2 == "-"* ]]
			then
				echo "Branch parameter needs a branch to use!"
				exit 1
			fi
			BRANCH=$2
			shift 2
		;;
		"-s"|"--source")
			if [ -z "$2" ]
			then
				echo "Source argument parameter needs a value!"
				exit 1
			fi
			SOURCE=$2
			shift 2
		;;
		"-i"|"--ignore")
			IGNORE_EXISTING=1
			shift 1
		;;
		"-ni"|"--non-interactive")
			INTERACTIVE=0
			shift 1
		;;
		"-fc"|"--full")
			FULL_CLONE=1
			shift 1
		;;
		*)
			echo "unknown parameter: $1"
			exit 1;
		;;
	esac
	
	PARAMETER_NUMBER=$(( $PARAMETER_NUMBER + 1 ))
done

if [ -z "$REPOSITORY" ]
then
	echo "No repository was set or could not be derived from other parameters"
	exit 1
fi

if [ -z "$FOLDER" ]
then
	echo "No folder was set or could not be derived from other parameters"
	exit 1
fi

RELENG=$REPOSITORY/$FOLDER

if [ -z $DESTINATION ]
then
	DIR=.
else 
	DIR=$DESTINATION
fi

if [ $INTERACTIVE -ne 0 ]
then
	read -p "Do you want to checkout $REPOSITORY into $(cd "$(dirname "$DIR")" && pwd)? y/N" PROCEED
	case "$PROCEED" in
		Yes|yes|Y|y)
			echo "Starting checkout..."
		;;
		No|no|N|n|""|*)
			echo "No changes"
			exit 1
		;;
	esac
fi

cd $DIR

#clone given releng repo

SOURCE_IS_HJP=0
case "$SOURCE" in
	PersoSim|persosim|PERSOSIM)
		CLONE_URI=git@github.com:PersoSim/
	;;
	GlobalTester|globaltester|gt|GT|GLOBALTESTER)
		CLONE_URI=git@github.com:GlobalTester/
	;;
	HJP|hjp|*)
		CLONE_URI=git@git.hjp-consulting.com:
		SOURCE_IS_HJP=1
	;;
esac

if [ $FULL_CLONE -eq 1 -a $SOURCE_IS_HJP -ne 1 ]
then
	echo "A full clone is only possible using the HJP servers."
	exit 1
fi

CLONERESULT=0
ACTUALLY_CLONED=

if [ $FULL_CLONE -eq 1 ]
then
	#extract repo names from git
	REPOS_TO_CLONE=`ssh git@git.hjp-consulting.com | sed -e '/^ R/!d' | sed "s/^[ RW\t]*//" | grep "\."`
else
	#clone releng repo
	if [ -d $REPOSITORY ]
	then
		if [ $IGNORE_EXISTING -eq 0 ]
		then
			echo Releng repository already existing
			exit 1
		else
			CLONERESULT=0
		fi
	else
		git clone ${CLONE_URI}${REPOSITORY}
	fi
		
	CLONERESULT=$?
	
	if [ $CLONERESULT -eq 0 ]
	then
		ACTUALLY_CLONED=${ACTUALLY_CLONED}"$REPOSITORY\n"
		if [ ! -z "$BRANCH" ]
		then
			cd "$REPOSITORY";git checkout "$BRANCH"; cd ..;
		fi
	fi
	
	
	#extract repo names from pom
	if [ -e $RELENG/pom.xml ]
	then
		REPOS_TO_CLONE=`cat $RELENG/pom.xml | grep '<module>' | sed -e 's|.*\.\.\/\.\.\/\([^/]*\)\/.*<\/module>|\1|' | grep -v "$REPOSITORY" | sort -u`
	else
		echo No releng pom file found to extract a file list from
		exit 1
	fi
fi

for currentRepo in $REPOS_TO_CLONE
do
	if [ $IGNORE_EXISTING -eq 1 -a -d $currentRepo ]
	then
		continue
	fi
	git clone ${CLONE_URI}$currentRepo
	CLONERESULT=$(( $CLONERESULT + $? ))
	if [ $CLONERESULT -ne 0 ]
	then
		break
	else
		ACTUALLY_CLONED=${ACTUALLY_CLONED}"$currentRepo\n"
	fi
done

if [ $CLONERESULT -eq 0 -a ! -z "$BRANCH" ]
then
	for curProj in */; do cd "$curProj";echo -en "\e[36m" ; pwd; echo -en "\e[0m"; git checkout "$BRANCH"; cd ..; done
fi


# print a little summary


echo -e "\n\n\n===================="
echo -e "Repos cloned\n"
echo -e $ACTUALLY_CLONED
echo "===================="

if [ $CLONERESULT -ne 0 ]
then
	echo "Clone was incomplete"
else
	echo "Checkout of $REPOSITORY and related in $DIR"
fi
echo "===================="
exit $CLONERESULT