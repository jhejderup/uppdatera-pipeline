#!/usr/bin/env bash

###
### Proper error codes in pipes
###
set -o pipefail

###
### VARIABLES
###
MVN_FLAGS="-Dcheckstyle.skip=true -Djacoco.skip=true \
-Dcobertura.skip=true -Dduplicate-finder.skip=true \
-Denforcer.skip=true -Dlicense.skipAddThirdParty=true \
-Dgpg.skip=true -Drat.skip=true -Dmaven.javadoc.skip=true \
-Dlicense.skip=true"
export REPO=$USER_HOME_DIR/repo
export JAR_DIR=target/uppdatera-bins
DATA=/data

###
### EXIT CODES
###
GIT_ERR=1
MVN_INSTALL_ERR=2
DIR_NOT_FOUND=4
export DEPS_NONE=5
export DEPS_MISMATCH=6
NO_TARGET_CLASSES=7


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
if ! mvn install source:jar "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-install-callsiteminer.log
then
  echo "[Uppdatera] build repository - fail!"
  exit $MVN_INSTALL_ERR
else
  echo "[Uppdatera] build repository - done!"
fi

###
### FIND MODULES 
###
echo "[Uppdatera] searching modules with 'classes' directory"
readarray -d '' modules < <(find "$REPO" -type d -wholename "*target/classes" -print0 | sed 's/\/target\/classes//g')

if [ ${#modules[@]} -eq 0 ]; then
    echo "[Uppdatera] no modules with 'test-classes' directory found"
    exit $NO_TARGET_CLASSES
fi

###
### RUN CALL-GRAPH GENERATION PER MODULE
###
for module in "${modules[@]}"
do
    if ! cd "$module"
    then
     echo "[Uppdatera][$module] $module does not exist anymore for strange reason"
     cd "$REPO" || exit $DIR_NOT_FOUND  
     continue
    fi 

    ###
    ### Create data folder for the module
    ###
    export MODULE_DATA=$DATA/${module#/root/}
    export MODULE_DATA_ERR=$MODULE_DATA/error
    export _DATA=$MODULE_DATA/callsites
    mkdir -p "$MODULE_DATA_ERR" 
    mkdir -p "$_DATA"


    ###
    ### Dump all dependencies
    ###
    if ! mvn -B dependency:copy-dependencies
    then
        echo "[Uppdatera][$module] mvn -B dependency:copy-dependencies  - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_COPY
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    ###
    ### CREATE FILE WITH DEP CLASSES
    ###
    touch DEP_CLASSES    
    for JARFILE in target/dependency/*.jar
    do
        jar tf "$JARFILE" | grep -v "module-info.class" | grep ".class" |  sed 's/......$//' >> DEP_CLASSES 
    done


    ###
    ### PROCESS PRODUCTION CLASSES
    ###
    touch PROD_METHODS
    shopt -s globstar
    for CLASSFILE in target/classes/**/*.class
    do    
        java -jar /root/uppdatera/target/bytecode-miner.jar "$CLASSFILE" PROD_METHODS
    done
    
    python3 /filter.py DEP_CLASSES PROD_METHODS

    if [[ -f CALLSITES ]]; then
        mv CALLSITES "$_DATA"/CALLSITES
    fi

    ###
    ### MOVE TO next module
    ###
    cd "$REPO" || exit $DIR_NOT_FOUND     
done