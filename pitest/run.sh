#!/usr/bin/env bash

###
### ARGS
###
DIR=$1
SLUG=$2
SHA=$3

###
### EXIT CODES
###
GIT_ERR=1
MVN_INSTALL_ERR=2
NO_TEST_CLASSES=3
DIR_NOT_FOUND=4
DEPS_NONE=5
DEPS_MISMATCH=6
ZERO_CG=7
INJECT_POM_FAIL=8
AGENT_FAIL=9

###
### How to runL time cat slugs-30oct.txt |  awk -F" " '{print $1" "$2}' | awk -F" " '{print "./images/uppdatera-docker/pitest/run.sh /data/uppdatera/docker/data2 "$1" "$2" "$3 }'|  parallel -j15 > pitest-run-11dec19.txt
###

###
### CREATE DIR
###
MOUNT_DIR=$DIR"/"$SLUG
mkdir -p "$MOUNT_DIR"

###
### RUN CG GENERATION
###
docker run --rm -v "$MOUNT_DIR":/data uppdatera-pitest "$SLUG"  "$SHA"   &> "$MOUNT_DIR"/docker.log
exitcode=$?

###
### CHECK EXIT CODE
###
[ $exitcode -eq $GIT_ERR ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (GIT)'
[ $exitcode -eq $MVN_INSTALL_ERR ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (MVN INSTALL)'
[ $exitcode -eq $NO_TEST_CLASSES ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (NO TESTS)'
[ $exitcode -eq $DIR_NOT_FOUND ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (DIR MISSING)'
[ $exitcode -eq $DEPS_NONE ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (DEPS_NONE)'
[ $exitcode -eq $DEPS_MISMATCH ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (DEPS_MISMATCH)'
[ $exitcode -eq $ZERO_CG ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (ZERO_CG)'
[ $exitcode -eq $INJECT_POM_FAIL ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (INJECT_POM_FAIL)'
[ $exitcode -eq $AGENT_FAIL ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (AGENT_FAIL)'
## 137 is SIGKILL for docker containers
[ $exitcode -eq 137 ] && echo -e "$SLUG"'\t'"$SHA"'\tFAIL (DOCKER KILL)'
if [ $exitcode -eq 0 ] 
then
    if ! find "$MOUNT_DIR" -name mutations.csv | grep -E ".*" > /dev/null
    then
        echo -e "$SLUG"'\t'"$SHA"'\tFAIL (PITest)'
    else
        echo -e "$SLUG"'\t'"$SHA"'\tSUCCESS'
    fi
fi