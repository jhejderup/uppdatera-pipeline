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
DATA=/data

###
### EXIT CODES
###
GIT_ERR=1
MVN_INSTALL_ERR=2
NO_TARGET_CLASSES=3
DIR_NOT_FOUND=4
export DEPS_NONE=5
export DEPS_MISMATCH=6
INJECT_POM_FAIL=7
AGENT_FAIL=8

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
if ! mvn install source:jar "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-install-stats.log
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
    export _DATA=$MODULE_DATA/stats
    mkdir -p "$MODULE_DATA_ERR" 
    mkdir -p "$_DATA" 


    ###
    ### DUMP DEPS & SOURCES IN LOCAL TARGET FOLDER
    ###
    echo "[Uppdatera] dump binary and source jars dependencies in local folders"
    
    if ! mvn -B dependency:copy-dependencies -DincludeScope=compile -DexcludeTransitive=true 
    then
        echo "[Uppdatera][$module] mvn -B dependency:copy-dependencies fail"
        touch "$MODULE_DATA_ERR"/DEPS_COPY
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    ###
    ### GEN ALL DIR DEP CLASSES
    ###
    for JARFILE in target/dependency/*.jar
    do
        jar tf "$JARFILE" | grep -v "module-info.class" | grep ".class" |  sed 's/......$//' >> "$_DATA"/DEP_CLASSES 
    done

    ###
    ### STATS OF DEPZ
    ###
    mvn dependency:build-classpath -Dmdep.outputFile="$_DATA"/ALL_DEP_CP
    mvn dependency:build-classpath -Dmdep.outputFile="$_DATA"/DIRECT_DEP_CP -DexcludeTransitive=true 

    ###
    ### Scrap call sites
    ###
    touch PROD_METHODS
    shopt -s globstar
    for CLASSFILE in target/classes/**/*.class
    do    
        java -jar /root/uppdatera/miner/target/bytecode-miner.jar "$CLASSFILE" PROD_METHODS
    done
    
    if [[ -f PROD_METHODS ]]; then
        mv PROD_METHODS "$_DATA"/PROD_METHODS
    fi

    ###
    ### Classes to track
    ###
    find target/classes -iname '*.class' | sed 's/......$//' | sed 's/target\/classes\///' > "$_DATA"/USER_CLASSES

    cat "$_DATA"/USER_CLASSES "$_DATA"/DEP_CLASSES  > "$_DATA"/cha-user.txt

    ###
    ### MOVE TO next module
    ###
    cd "$REPO" || exit $DIR_NOT_FOUND    
done

cd "$REPO" || exit $DIR_NOT_FOUND  


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
if ! mvn -X test -Puppdatera -Dagent.uppdatera="$AGENT" "$MVN_FLAGS" 2>&1 | tee $DATA/mvn-agent-stats.log
then
  echo "[Uppdatera] dynamic call graph - fail!"
  exit $AGENT_FAIL
else
  echo "[Uppdatera] dynamic call graph - done!"
fi

exit 0