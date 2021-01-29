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
AGENT=" '-XX:OnOutOfMemoryError=kill -9 %p' \
-Xbootclasspath/p:$UPPD/agent-bootstrap.jar \
-javaagent:$UPPD/agent.jar"
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
NO_TEST_CLASSES=3
DIR_NOT_FOUND=4
export DEPS_NONE=5
export DEPS_MISMATCH=6
ZERO_CG=7
INJECT_POM_FAIL=8
AGENT_FAIL=9

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
if ! mvn install source:jar "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-install.log
then
  echo "[Uppdatera] build repository - fail!"
  exit $MVN_INSTALL_ERR
else
  echo "[Uppdatera] build repository - done!"
fi


###
### FIND MODULES 
###
echo "[Uppdatera] searching modules with 'test-classes' directory"
readarray -d '' modules < <(find "$REPO" -type d -wholename "*target/test-classes" -print0 | sed 's/\/target\/test-classes//g')

if [ ${#modules[@]} -eq 0 ]; then
    echo "[Uppdatera] no modules with 'test-classes' directory found"
    exit $NO_TEST_CLASSES
fi

printf '[uppdatera] found the following modules with test-classes: %s\n' "${modules[@]}"

hasCallgraph=false

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
    export CG_DATA=$MODULE_DATA/callgraph
    mkdir -p "$MODULE_DATA_ERR" 
    mkdir -p "$CG_DATA" 
    export SRC_DEP_FILE=$MODULE_DATA/sources-list.txt
    export BIN_DEP_FILE=$MODULE_DATA/binaries-list.txt

    ###
    ### RESOLVE DEPS & DUMP COORDS,JAR PATHS
    ###
    if ! mvn dependency:sources -DoutputAbsoluteArtifactFilename -DoutputFile="$SRC_DEP_FILE" -DincludeScope=compile
    then
        echo "[Uppdatera][$module] mvn dependency:sources - fail!"
         touch "$MODULE_DATA_ERR"/DEPS_SRC_JAR
         cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    else
        echo "[Uppdatera][$module] mvn dependency:sources - success!" 
    fi
   
    if ! mvn dependency:list -DoutputAbsoluteArtifactFilename -DoutputFile="$BIN_DEP_FILE" -DincludeScope=compile
    then
        echo "[Uppdatera][$module] mvn dependency:list - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_LST_JAR
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    else
        echo "[Uppdatera][$module] mvn dependency:list - success!"         
    fi

    ###
    ### DUMP DEPS & SOURCES IN LOCAL TARGET FOLDER
    ###
    echo "[Uppdatera] dump binary and source jars dependencies in local folders"
    
    if ! mvn -B dependency:copy-dependencies
    then
        echo "[Uppdatera][$module] mvn -B dependency:copy-dependencies for PITest - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_COPY
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi
    
    if ! mvn -B dependency:copy-dependencies -Dclassifier=sources -DoutputDirectory="$SRC_JAR_DIR" -DincludeScope=compile
    then
        echo "[Uppdatera][$module] mvn -B dependency:copy-dependencies -Dclassifier=sources -DoutputDirectory=$SRC_DIR -DincludeScope=runtime - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_COPY_SRCJAR
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi
    
    if ! mvn -B dependency:copy-dependencies -DoutputDirectory="$JAR_DIR" -DincludeScope=compile
    then
        echo "[Uppdatera][$module] mvn -B dependency:copy-dependencies -DoutputDirectory=$BIN_DIR -DincludeScope=runtime - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_COPY_JAR
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    ###
    ### PROCESS DEPS & ENSURE CONSISTENCY
    ###
    python3 /prune_deps.py
    exitcode=$?
    if [ $exitcode -eq $DEPS_NONE ]
    then 
        echo "[Uppdatera][$module] no dependencies in sources or binaries dir - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_NO
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ $exitcode -eq $DEPS_MISMATCH ]
    then 
        echo "[Uppdatera][$module] there is a mismatch with the number of dependencies in both folders - fail!"
        touch "$MODULE_DATA_ERR"/DEPS_MISMATCH
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    ###
    ### Build CG with WALA
    ###
    if ! java -jar "$UPPD"/uppdatera.jar "$CG_DATA" "$JAR_DIR" 
    then
        echo "[Uppdatera][$module] java -jar $UPPD/uppdatera.jar $MODULE_DATA - fail!"
        touch "$MODULE_DATA_ERR"/NO_CG
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ "$(find "$CG_DATA" -type f | wc -l)" -ne 2 ]
    then
        echo "[Uppdatera][$module] java -jar $UPPD/uppdatera.jar $MODULE_DATA - fail!"
        touch "$MODULE_DATA_ERR"/MISSING_CG_FILES
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ "$(cat "$CG_DATA"/cg.txt | wc -w)" -eq 0 ]
    then
        echo "[Uppdatera][$module] NO VALID DEPENDENCY CALLS"
        touch "$MODULE_DATA_ERR"/NO_CALLS
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ "$(cat "$CG_DATA"/cha.txt | wc -w)" -eq 0 ]
    then
        echo "[Uppdatera][$module] NO VALID CLASSES iN CHA"
        touch "$MODULE_DATA_ERR"/NO_CLASSES
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    hasCallgraph=true
        
    ###
    ### MOVE TO next module
    ###
    cd "$REPO" || exit $DIR_NOT_FOUND    
done

cd "$REPO" || exit $DIR_NOT_FOUND  

###
### AGENT UPPDATERA TO THE RESCUE!
###

if [ "$hasCallgraph" = false ]; then
    exit $ZERO_CG
fi

###
### REWRITE POM FILE
###
python3 /inject_pom_profile.py .
exitcode=$?
if [ $exitcode -ne 0 ]
then 
    echo "[Uppdatera] Could not inject a profile in the pom file "
    exit $INJECT_POM_FAIL
fi

###
### RUN AGENT
###
 echo "[Uppdatera] starting dynamic call graph generation"   
if ! mvn -X test -Puppdatera -Dagent.uppdatera="$AGENT" "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-agent-test.log
then
  echo "[Uppdatera] dynamic call graph - fail!"
  exit $AGENT_FAIL
else
  echo "[Uppdatera] dynamic call graph - done!"
fi

exit 0