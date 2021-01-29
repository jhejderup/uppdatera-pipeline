#!/usr/bin/env bash

###
### Proper error codes in pipes
###
set -o pipefail

###
### VARIABLES
###
MVN_FLAGS="-Dmaven.test.skip=true -DskipTests=true -Dcheckstyle.skip=true -Djacoco.skip=true \
-Dcobertura.skip=true -Dduplicate-finder.skip=true \
-Denforcer.skip=true -Dlicense.skipAddThirdParty=true \
-Dgpg.skip=true -Drat.skip=true -Dmaven.javadoc.skip=true \
-Dlicense.skip=true"
export REPO=$USER_HOME_DIR/repo
export SRC_JAR_DIR=target/uppdatera-srcs/compressed
export SRC_JAR_DE=target/uppdatera-srcs/decompressed
export JAR_DIR=target/uppdatera-bins
DATA=/data

###
### EXIT CODES
###
GIT_ERR=1
MVN_INSTALL_ERR=2
MISSING_ARG=3
DIR_NOT_FOUND=4
export DEPS_NONE=5
export DEPS_MISMATCH=6
PATH_NOT_EXIST=7
CLASSES_NOT_EXIST=8
NO_REPORT_FILE=10
NOT_A_NICE_DEP=11


###
### FILTER
###
if [[ $4 == *"junit"* || $4 == *"cucumber"* || $4 == *"maven"*   || $4 == *"mockito"* || $4 == *"testng"* ]]; then
  echo "[Uppdatera] our filter doesnt like this dependency"
  exit $NOT_A_NICE_DEP
fi

if [[ $5 == *"junit"* || $5 == *"cucumber"* || $5 == *"maven"*   || $5 == *"mockito"* || $5 == *"testng"* ]]; then
  echo "[Uppdatera] our filter doesnt like this dependency"
  exit $NOT_A_NICE_DEP
fi


###
### CLONE REPOSITORY
###
if ! git clone https://github.com/"$1" "$REPO"
then
  echo "[Uppdatera] clone https://github.com/$1 into $REPO - fail!"
  exit $GIT_ERR
else
  echo "[Uppdatera] clone https://github.com/$1 into $REPO - done!"
fi

cd "$REPO" || exit $DIR_NOT_FOUND
if [ -n "$2" ]
then
    if ! git checkout "$2"
    then
        echo "[Uppdatera] checkout commit $2 - fail! "
        exit $GIT_ERR    
    else
        echo "[Uppdatera] checkout commit $2 - done!"
    fi        
fi

###
### store commit
###
git log --pretty=format:'%h' -n 1 > $DATA/COMMIT

###
### BUILD REPOSITORY
###
if ! mvn install source:jar -Dmaven.test.skip=true  -DskipTests "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-install.log
then
  echo "[Uppdatera] build repository - fail!"
  exit $MVN_INSTALL_ERR
else
  echo "[Uppdatera] build repository - done!"
fi

###
### Go to folder hosting the pom.xml file
###

if [ -z "$3" ]
then
    echo "[Uppdatera] missing <path> argument"
    exit $MISSING_ARG
fi

if [ "$3" != "pom.xml" ]
then
    D=$(echo "$3" | sed  's/\/pom\.xml//')
    cd "$D" || exit "$PATH_NOT_EXIST"
fi


###
### Build classpath
###

echo "Current analysis directory -- $(pwd)"

if [ ! -d "target/classes" ]
then
    echo "target/classes is missing!"
    exit $CLASSES_NOT_EXIST
fi

###
### Run Uppdatera
###


java -jar "$UPPD"/uppdatera.jar target/classes "$4" "$5" "$6" "$7" 2>&1 | tee $DATA/uppdatera.log
exitcode=$?
if [ $exitcode -ne 0 ]
then 
    echo "[Uppdatera] An error occured - inspect the log file for the error"
    exit $exitcode
fi

if [ ! -f "report.md" ]
then
    echo "[Uppdatera] report.md file missing!"
    exit $NO_REPORT_FILE
fi

HTML_LINK=$(echo "$9" | sed 's/https\:\/\/api\.github\.com\/repos\//https\:\/\/github\.com\//' | sed 's/\/pulls\//\/pull\//')

echo "$9" > $DATA/PR_URL

mv report.md $DATA/report.md

###
### Post issue!
###

echo "[Uppdatera] posting issue on Github"
python3 /post_issue.py $DATA/report.md  "$1" "$HTML_LINK" "$8"

if [[ -f ISSUE_URL ]]; then
   mv ISSUE_URL $DATA/ISSUE_URL
fi

if [[ -f ISSUE_CLOSED ]]; then
   mv ISSUE_CLOSED $DATA/ISSUE_CLOSED
fi

