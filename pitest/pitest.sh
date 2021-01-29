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
export SRC_JAR_DIR=target/uppdatera-srcs/compressed
export SRC_JAR_DECOMP=target/uppdatera-srcs/decompressed
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
export PITARGS_FAIL=7
export PITARGS_EXCLASS_FAIL=8
export PITARGS_EXCLASS_FILE_FAIL=9

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

###
### RUN CALL-GRAPH GENERATION PER MODULE
###
for module in "${modules[@]}"
do
    if ! cd "$module"
    then
     echo "[Uppdatera][$module] $module does not exist anymore for strange reason"
     continue
    fi 

    ###
    ### RESOLVE DEPS & DUMP COORDS,JAR PATHS
    ###
    # if ! mvn dependency:sources -DoutputAbsoluteArtifactFilename -DoutputFile="$SRC_DEP_FILE" -DincludeScope=compile
    # then
    #     echo "[Uppdatera][$module] mvn dependency:sources - fail!"
    #     touch "$MODULE_DATA_ERR"/DEPS_SRC_JAR
    #     continue
    # else
    #     echo "[Uppdatera][$module] mvn dependency:sources - success!" 
    # fi
   
    # if ! mvn dependency:list -DoutputAbsoluteArtifactFilename -DoutputFile="$BIN_DEP_FILE" -DincludeScope=compile
    # then
    #     echo "[Uppdatera][$module] mvn dependency:list - fail!"
    #     touch "$MODULE_DATA_ERR"/DEPS_LST_JAR
    #     continue
    # else
    #     echo "[Uppdatera][$module] mvn dependency:list - success!"         
    # fi

    ###
    ### Create data folder for the module
    ###
    export MODULE_DATA=$DATA/${module#/root/}
    export MODULE_DATA_ERR=$MODULE_DATA/error
    export PIT_DATA=$MODULE_DATA/pitest
    mkdir -p "$MODULE_DATA_ERR" 
    mkdir -p "$PIT_DATA" 
    export SRC_DEP_FILE=$MODULE_DATA/sources-list.txt
    export BIN_DEP_FILE=$MODULE_DATA/binaries-list.txt

    ###
    ### DUMP DEPS & SOURCES IN LOCAL TARGET FOLDER
    ###
    
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
    ### UNZIP STUFF
    ###
    echo "[Uppdatera] unzip source jars into $SRC_JAR_DECOMP"
    # create folder first
    mkdir -p $SRC_JAR_DECOMP
    for src_jar in "$SRC_JAR_DIR"/*.jar; do
        name=$(basename "$src_jar" .jar)
        target=$SRC_JAR_DECOMP"/"$name
        mkdir -p "$target"
        if ! unzip -o -qq "$src_jar" -d "$target"
        then
            echo "[Uppdatera][$module] unzip -qq $src_jar -d $target - fail!"
            touch "$MODULE_DATA_ERR"/UNZIP_SRC_JAR
            cd "$REPO" || exit $DIR_NOT_FOUND  
            continue
        fi    
    done

    ## uncomment for verificationn
    ##   find $SRC_JAR_DECOMP -regex ".*\.\(java\)"

    echo "[Uppdatera] unzip dependency classes into target/classes"
    for jar in "$JAR_DIR"/*.jar; do
        if ! unzip -o -qq "$jar" -d target/classes "*.class"
        then
            echo "[Uppdatera][$module] unzip -qq $jar -d target/classes *.class - fail!"
            touch "$MODULE_DATA_ERR"/UNZIP_JAR
            cd "$REPO" || exit $DIR_NOT_FOUND  
            continue
        fi   
    done

    ###
    ### RUN PITEST!
    ###

    #
    #  Check if we have the call graphs
    #
    if [ ! -f "$MODULE_DATA"/callgraph/cha.txt ]; then
        echo "[Uppdatera][$module] $MODULE_DATA/callgraph/cha.txt is missing !"
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ ! -f "$MODULE_DATA"/callgraph/dyn-cg.txt ]; then
        echo "[Uppdatera][$module] $MODULE_DATA/callgraph/dyn-cg.txt is missing !"
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    echo "[Uppdatera] generate PITest cmd line"
    python3 /pit_args.py target/test-classes "$MODULE_DATA"/callgraph/cha.txt "$MODULE_DATA"/callgraph/dyn-cg.txt $SRC_JAR_DECOMP
    exitcode=$?
    if [ $exitcode -eq $PITARGS_FAIL ]
    then 
        echo "[Uppdatera][$module] generating arguments failed!"
        touch "$MODULE_DATA_ERR"/PIT_ARGS_FAIL
        cd "$REPO" || exit $DIR_NOT_FOUND  
        continue
    fi

    if [ ! -f "$PIT_DATA"/args.pit ]; then
         echo "[Uppdatera][$module] arguments file missing !"
         cd "$REPO" || exit $DIR_NOT_FOUND  
         continue
    fi

    echo "[Uppdatera] run PITest"

    keep_trying=1
    i=1
    DEP_CP_COMPILE=$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/fd/4 4>&1 >/dev/null)
    while [ $keep_trying -eq 1 ]
    do
        keep_trying=0
        PIT_ARGS=$(head -n 1 "$PIT_DATA"/args.pit)
        if ! java -cp $PIT_TEST_DEPS/*:target/test-classes:target/classes:"$DEP_CP_COMPILE":$PIT_RUNTIME/* org.pitest.mutationtest.commandline.MutationCoverageReport $PIT_ARGS 2>&1 | tee "$MODULE_DATA"/pitest-"$i".log
        then
            echo "[Uppdatera] PITest failed; lets try with adding test dependencies"
            bash /fix_pit_args.sh "$MODULE_DATA"/pitest-"$i".log "$PIT_DATA"/args.pit
            exitcode=$?
            if [ $exitcode -eq 0 ]
            then
                i=$((i+1))
                keep_trying=1
                echo "[Uppdatera][$module] re-run pit with exlcusion filter!"
            else
                keep_trying=0
                echo "[Uppdatera][$module] unknown error and terminate the loop"                
            fi
        fi
    done

    ###
    ### MOVE TO next module
    ###
    cd "$REPO" || exit $DIR_NOT_FOUND    
done

exit 0