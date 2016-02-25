#!/bin/bash
# must be called from root directory for all repos
set -e
. org.globaltester.dev/org.globaltester.dev.tools/scripts/helper.sh
. org.globaltester.dev/org.globaltester.dev.tools/scripts/projectHelper.sh
set +e

METAINFDIR='META-INF'
MANIFESTFILE='MANIFEST.MF'
PROJECTFILE='.project'

TESTSCRIPTSIDENTIFIER="testscripts"



FINDDIRRESULT=""
function findDir(){
	CURRENTRAWDEPENDENCY="$1"
	MYPATH="$2"
	
	PREVDEPTMP=""
	CURRDEPTMP="$CURRENTRAWDEPENDENCY"
	
	#echo INFO: curr wdir is `pwd`
	
	while [[ ! -d "$MYPATH/$CURRDEPTMP" ]]
	do
		PREVDEPTMP="$CURRDEPTMP"
		CURRDEPTMP=$(echo "$PREVDEPTMP" | rev | cut -d '.' -f 2- | rev)
		if [[ "$CURRDEPTMP" == "$PREVDEPTMP" ]]
			then
				#echo WARNING: did not find directory matching "$CURRENTRAWDEPENDENCY"!
				return 1
		fi
	done
	
	FINDDIRRESULT="$CURRDEPTMP"
	
	return 0
}



BASEDIR=`pwd`
echo INFO: base dir is \""$BASEDIR"\"
CURRENT_REPO=$1
echo INFO: current repo is \""$CURRENT_REPO"\"

if [[ -d $CURRENT_REPO && $CURRENT_REPO != '.' && $CURRENT_REPO != '..' ]]
	then	
		CURRENT_REPO=$(echo $CURRENT_REPO | cut -d '/' -f 1)
		echo INFO: current repo is \""$CURRENT_REPO"\"
		
		for CURRENT_PROJECT in $CURRENT_REPO/*/
			do
				CURRENT_PROJECT=`basename $CURRENT_PROJECT`
				PATHTOPROJECT="$CURRENT_REPO/$CURRENT_PROJECT"
				if [[ -d $PATHTOPROJECT && $PATHTOPROJECT != '.' && $PATHTOPROJECT != '..' ]]
					then
						echo ================================================================
						#CURRENT_PROJECT=$(echo $CURRENT_PROJECT | cut -d '/' -f 1)
						PATHTOMANIFESTMF="$PATHTOPROJECT/META-INF/MANIFEST.MF"
						echo INFO: currently checked project is: \""$CURRENT_REPO/$CURRENT_PROJECT"\"
						
						# find required classes or packages
						
						DEBUG=`echo "$CURRENT_REPO" | grep "$TESTSCRIPTSIDENTIFIER"`
						GREPRESULT=$?
						
						if [[ $GREPRESULT == '0' ]]
							then
								# this is a testscripts project
								echo INFO: this is a testscripts project
								TESTSCRIPTSPROJECT=true
								RAWDEPENDENCIES="";
								
								# get all direct dependencies from *.js and *.xml
								PATHTOHELPER="$PATHTOPROJECT"/Helper
								if [[ -d "$PATHTOHELPER" && "$PATHTOHELPER" != '.' && "$PATHTOHELPER" != '..' ]]
									then
										echo INFO: parsing "$PATHTOHELPER"
										RAWDEPENDENCIESJS=`find "$PATHTOHELPER" -name *.js -exec  sed -n -e 's@.*\(\(com\.hjp\|de\.persosim\|org\.globaltester\)\(\.\w\+\)\+\).*@\1@gp' {} \; | sort -u`
										RAWDEPENDENCIES="$RAWDEPENDENCIESJS"
								fi
								
								PATHTOTESTSUITES="$PATHTOPROJECT"/TestSuites
								if [[ -d "$PATHTOTESTSUITES" && "$PATHTOTESTSUITES" != '.' && "$PATHTOTESTSUITES" != '..' ]]
									then
										echo INFO: parsing "$PATHTOTESTSUITES"
										RAWDEPENDENCIESXML=`find "$PATHTOTESTSUITES" -name *.xml -exec  sed -n -e 's@.*\(\(com\.hjp\|de\.persosim\|org\.globaltester\)\(\.\w\+\)\+\).*@\1@gp' {} \; | sort -u`
										RAWDEPENDENCIES="$RAWDEPENDENCIES
""$RAWDEPENDENCIESXML"
										RAWDEPENDENCIES="$(echo -e "${RAWDEPENDENCIES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
								fi
								
								RAWDEPENDENCIES=`echo "$RAWDEPENDENCIES" | sort -u`
								RAWDEPENDENCIES=`echo "$RAWDEPENDENCIES" | sed -e "s|\(.*\)\..*|\1|" | sort -u`
							else
								# this is a code project
								echo INFO: this is a code project
								TESTSCRIPTSPROJECT=false
								RAWDEPENDENCIESJAVA=`find "$PATHTOPROJECT"/src -name *.java -exec  sed -n -e 's@.*\(\(com\.hjp\|de\.persosim\|org\.globaltester\)\(\.\w\+\)\+\).*@\1@gp' {} \; | sort -u`
								RAWDEPENDENCIES="$RAWDEPENDENCIESJAVA"
						fi
						
						RAWDEPENDENCIES="$(echo -e "${RAWDEPENDENCIES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
						
						count=0
						echo INFO: found the following raw dependencies
						while read -r CURRENTRAWDEPENDENCY
						do
							echo INFO: \($count\) "$CURRENTRAWDEPENDENCY"
							count=$((count+1))
						done <<< "$RAWDEPENDENCIES"
						echo INFO: -$count- elements
						
						CLEANDEPENDENCIES=""
						while read -r CURRENTRAWDEPENDENCY
						do
							echo ----------------------------------------------------------------
							echo "DEBUG: current raw dependency: $CURRENTRAWDEPENDENCY"
							
							findDir "$CURRENTRAWDEPENDENCY" "."
							FINDDIREXITSTATUS=$?
							
							# greedily find repository containing the raw dependency
							if [[ $FINDDIREXITSTATUS != '0' ]]
								then
									echo WARNING: did not find directory matching "$CURRENTRAWDEPENDENCY" in \.!
									continue
							fi
							
							CURRDEPREPO=$FINDDIRRESULT
							echo INFO: parent repository of "$CURRENTRAWDEPENDENCY" is "$CURRDEPREPO"
							
							#----------------------------------------------------------------
							
							# greedily find project containing the raw dependency
							findDir "$CURRENTRAWDEPENDENCY" "$CURRDEPREPO"
							FINDDIREXITSTATUS=$?
							
							if [[ $FINDDIREXITSTATUS != '0' ]]
								then
									echo WARNING: did not find directory matching "$CURRENTRAWDEPENDENCY" in "$CURRDEPREPO"!
									continue
							fi
							
							CURRDEPPROJECT=$FINDDIRRESULT
							
							# save project containing the raw dependency
							CLEANDEPENDENCIES=`echo -e "$CLEANDEPENDENCIES"'\n'"$CURRDEPPROJECT"`
							echo INFO: parent project of "$CURRENTRAWDEPENDENCY" is "$CURRDEPPROJECT"
							
						done <<< "$RAWDEPENDENCIES"
						
						echo ----------------------------------------------------------------
						
						# add indirect dependencies via load from *.js and *.xml
						if [[ $TESTSCRIPTSPROJECT ]]
							then
								# get all indirect dependencies via load from *.js and *.xml
								RAWDEPENDENCIESJSXMLLOAD=""
								
								if [[ -d "$PATHTOHELPER" && "$PATHTOHELPER" != '.' && "$PATHTOHELPER" != '..' ]]
									then
										echo INFO: parsing "$PATHTOHELPER"
										RAWDEPENDENCIESJSLOAD=`find "$PATHTOHELPER" -name *.js -exec grep "^[[:space:]]*load[[:space:]]*([[:space:]]*\".*\"[[:space:]]*," {} \;`
										RAWDEPENDENCIESJSXMLLOAD="$RAWDEPENDENCIESJSLOAD"
								fi
								
								if [[ -d "$PATHTOTESTSUITES" && "$PATHTOTESTSUITES" != '.' && "$PATHTOTESTSUITES" != '..' ]]
									then
										echo INFO: parsing "$PATHTOTESTSUITES"
										RAWDEPENDENCIESXMLLOAD=`find "$PATHTOTESTSUITES" -name *.xml -exec grep "^[[:space:]]*load[[:space:]]*([[:space:]]*\".*\"[[:space:]]*," {} \;`
										RAWDEPENDENCIESJSXMLLOAD="$RAWDEPENDENCIESJSXMLLOAD
""$RAWDEPENDENCIESXMLLOAD"
										RAWDEPENDENCIESJSXMLLOAD="$(echo -e "${RAWDEPENDENCIESJSXMLLOAD}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
								fi
								
								RAWDEPENDENCIESJSXMLLOAD=`echo "$RAWDEPENDENCIESJSXMLLOAD" | sort -u`
								
								# strip load commands down to Bundle-Name for each bundle
								BUNDLENAME=`extractFieldFromManifest "$PATHTOMANIFESTMF" "Bundle-Name"`
								
								CLEANEDBUNDLENAMES=""
								while read -r CURRDEP
								do
									CLEANEDBUNDLENAME=`echo "$CURRDEP" | cut -d '"' -f 2 | cut -d '"' -f 1`
									
									if [[ "$CLEANEDBUNDLENAME" != "$BUNDLENAME" ]]
										then
											CLEANEDBUNDLENAMES="$CLEANEDBUNDLENAMES""$CLEANEDBUNDLENAME
"
									fi
								
								done <<< "$RAWDEPENDENCIESJSXMLLOAD"
								
								CLEANEDBUNDLENAMES=`echo "$CLEANEDBUNDLENAMES" | sort -u`
								CLEANEDBUNDLENAMES="$(echo -e "${CLEANEDBUNDLENAMES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
								
								if [[ "$CLEANEDBUNDLENAMES" != "" ]]
									then
										count=0
										echo INFO: found the following loads
										while read -r CURRDEP
										do
											echo INFO: load \($count\) "$CURRDEP"
											count=$((count+1))
										done <<< "$CLEANEDBUNDLENAMES"
										echo INFO: load -$count- elements
										
										# find MANIFEST.MF files matching each Bundle-Name entry
										MANIFESTFILES=`find "." -mindepth 4 -maxdepth 4 -name MANIFEST.MF `
										
										LOADEDPROJECTS=""
										while read -r CURRBUNDLENAME
										do	
											echo INFO: looking up MANIFEST.MF with Bundle-Name:"$CURRBUNDLENAME"
											CURRMANIFESTBUNDLESYMBOLICNAME=""
											
											while read -r CURRMANIFEST
											do
												CURRMANIFESTBUNDLENAME=`extractFieldFromManifest "$CURRMANIFEST" "Bundle-Name"`
												if [[ "$CURRBUNDLENAME" != "$CURRMANIFESTBUNDLENAME" ]]
													then
														continue
												fi
												
												CURRMANIFESTBUNDLESYMBOLICNAME=`extractFieldFromManifest "$CURRMANIFEST" "Bundle-SymbolicName"`
												
												echo INFO: found Bundle-Name "$CURRBUNDLENAME" in "$CURRMANIFEST"
												echo INFO: matching Bundle-SymbolicName is: "$CURRMANIFESTBUNDLESYMBOLICNAME"
												break
											done <<< "$MANIFESTFILES"
											
											if [[ "$CURRMANIFESTBUNDLESYMBOLICNAME" == "" ]]
												then
													echo WARNING: unable to find project with Bundle-Name "$CURRBUNDLENAME"
													continue
											fi
											
											LOADEDPROJECTS="$LOADEDPROJECTS
""$CURRMANIFESTBUNDLESYMBOLICNAME"
											
										done <<< "$CLEANEDBUNDLENAMES"
										
										LOADEDPROJECTS="$(echo -e "${LOADEDPROJECTS}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
										
										count=0
										echo INFO: found the following loads
										while read -r CURRDEP
										do
											echo INFO: load \($count\) "$CURRDEP"
											count=$((count+1))
										done <<< "$LOADEDPROJECTS"
										echo INFO: load -$count- elements
										
										CLEANDEPENDENCIES="$CLEANDEPENDENCIES
""$LOADEDPROJECTS"
									else
										echo INFO: no indirect dependencies from load
								fi
								
								echo ----------------------------------------------------------------
						fi
						
						# ----------------------------------------------------------------
						
						UDEPS=`echo "$CLEANDEPENDENCIES" | sort -u`
						UDEPS="$(echo -e "${UDEPS}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
						
						# ----------------------------------------------------------------
						
						# filter self dependency
						echo INFO: filtering self-dependency
						MANIFESTBUNDLESYMBOLICNAME=`extractFieldFromManifest "$PATHTOMANIFESTMF" "Bundle-SymbolicName"`
						NEWUDEPS=""
						while read -r CURRENTDEPENDENCY
						do
							if [[ "$CURRENTDEPENDENCY" != "$MANIFESTBUNDLESYMBOLICNAME" ]]
								then
									NEWUDEPS="$NEWUDEPS
""$CURRENTDEPENDENCY"
								else
									echo INFO: skipped self-dependency \""$CURRENTDEPENDENCY"\"
							fi
						done <<< "$UDEPS"
						NEWUDEPS="$(echo -e "${NEWUDEPS}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')"
						UDEPS="$NEWUDEPS"
						
						echo ----------------------------------------------------------------
						
						# list all final dependencies
						if [[ "$UDEPS" != "" ]]
							then
								count=0
								echo INFO: found the following parsed unique dependencies in $TESTSCRIPTSIDENTIFIER project
								while read -r CURRENTRAWDEPENDENCY
								do
									echo INFO: \($count\) "$CURRENTRAWDEPENDENCY"
									count=$((count+1))
								done <<< "$UDEPS"
								echo INFO: -$count- elements
							else
								echo INFO: there are no parsed dependencies
						fi
						
						echo ----------------------------------------------------------------
						
						# extract and list all requirements listed in the MANIFEST.MF of the test script project
						MANIFESTREQS=`extractFieldFromManifest "$PATHTOMANIFESTMF" "Require-Bundle"`
						
						if [[ "$MANIFESTREQS" != "" ]]
							then
								count=0
								echo INFO: found the following unique dependencies in $PATHTOMANIFESTMF
								while read -r CURRDEP
								do
									echo INFO: \($count\) "$CURRDEP"
									count=$((count+1))
								done <<< "$MANIFESTREQS"
								echo INFO: -$count- elements
							else
								echo INFO: there are no dependencies defined in "$PATHTOMANIFESTMF"
						fi
						
						echo ----------------------------------------------------------------
						
						# match dependencies from script project against requirements defined in MANIFEST.MF
						if [[ "$UDEPS" != "" ]]
							then
								while read -r CURRDEPEXPECTED
								do
									GREPREQS=`echo "$MANIFESTREQS" | grep "$CURRDEPEXPECTED"`
									GREPEXITSTATUS=$?
									
									if [[ $GREPEXITSTATUS != '0' ]]
										then
											echo WARNING: missing requirement "$CURRDEPEXPECTED" in "$PATHTOMANIFESTMF"!
											continue
										else
											echo INFO: found dependency for "$CURRDEPEXPECTED" in "$PATHTOMANIFESTMF"!
									fi
									
								done <<< "$UDEPS"
							else
								echo INFO: not missing any requirements in "$PATHTOMANIFESTMF"
						fi
						
						echo ----------------------------------------------------------------
						
						# match dependencies from script project against requirements defined in MANIFEST.MF
						if [[ "$MANIFESTREQS" != "" ]]
							then
								while read -r CURRDEPEXPECTED
								do
									GREPREQS=`echo "$UDEPS" | grep "$CURRDEPEXPECTED"`
									GREPEXITSTATUS=$?
									
									if [[ $GREPEXITSTATUS != '0' ]]
										then
											echo WARNING: potentially obsolete requirement "$CURRDEPEXPECTED" in "$PATHTOMANIFESTMF"!
											continue
										else
											echo INFO: found dependency for "$CURRDEPEXPECTED" in "$PATHTOMANIFESTMF"!
									fi
									
								done <<< "$MANIFESTREQS"
							else
								echo INFO: there are definitely not too many requirements in "$PATHTOMANIFESTMF"
						fi
						
						echo ----------------------------------------------------------------
						
						# extend script here
					
					else
						echo WARNING: illegal project name "$CURRENT_PROJECT"
				fi
			done
	else
		echo WARNING: illegal repo name "$CURRENT_REPO"
fi

echo Script finished successfully

exit 0
