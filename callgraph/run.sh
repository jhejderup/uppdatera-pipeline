#!/usr/bin/env bash

###
### ARGS
###
DIR=$1
SLUG=$2

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
### CREATE DIR
###
MOUNT_DIR=$DIR"/"$SLUG
mkdir -p "$MOUNT_DIR"

###
### RUN CG GENERATION
###
docker run --rm -v "$MOUNT_DIR":/data uppdatera-callgraph "$SLUG"  &> "$MOUNT_DIR"/docker.log
exitcode=$?

###
### CHECK EXIT CODE
###
[ $exitcode -eq $GIT_ERR ] && echo -e "$SLUG"'\tFAIL (GIT)'
[ $exitcode -eq $MVN_INSTALL_ERR ] && echo -e "$SLUG"'\tFAIL (MVN INSTALL)'
[ $exitcode -eq $NO_TEST_CLASSES ] && echo -e "$SLUG"'\tFAIL (NO TESTS)'
[ $exitcode -eq $DIR_NOT_FOUND ] && echo -e "$SLUG"'\tFAIL (DIR MISSING)'
[ $exitcode -eq $DEPS_NONE ] && echo -e "$SLUG"'\tFAIL (DEPS_NONE)'
[ $exitcode -eq $DEPS_MISMATCH ] && echo -e "$SLUG"'\tFAIL (DEPS_MISMATCH)'
[ $exitcode -eq $ZERO_CG ] && echo -e "$SLUG"'\tFAIL (ZERO_CG)'
[ $exitcode -eq $INJECT_POM_FAIL ] && echo -e "$SLUG"'\tFAIL (INJECT_POM_FAIL)'
[ $exitcode -eq $AGENT_FAIL ] && echo -e "$SLUG"'\tFAIL (AGENT_FAIL)'
## 137 is SIGKILL for docker containers
[ $exitcode -eq 137 ] && echo -e "$SLUG"'\tFAIL (DOCKER KILL)'
[ $exitcode -eq 0 ] && echo -e "$SLUG"'\tSUCCESS'