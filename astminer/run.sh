#!/usr/bin/env bash

### How to use it
### ./run.sh <mountdir> <slug> <sha>
###


###
### ARG MOUNTS
###
MOUNT_DIR=$1
SLUG=$2
SHA=$3

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
### RUN AST GENERATION
###
docker run --rm -v "$MOUNT_DIR":/data uppdatera-callsiteminer "$SLUG" "$SHA"  &> "$MOUNT_DIR"/docker-callsiteminer.log
exitcode=$?

###
### CHECK EXIT CODE
###
[ $exitcode -eq $GIT_ERR ] && echo -e "$SLUG"'\tFAIL (GIT)'
[ $exitcode -eq $MVN_INSTALL_ERR ] && echo -e "$SLUG"'\tFAIL (MVN INSTALL)'
[ $exitcode -eq $NO_TARGET_CLASSES ] && echo -e "$SLUG"'\tFAIL (NO TESTS)'
[ $exitcode -eq $DIR_NOT_FOUND ] && echo -e "$SLUG"'\tFAIL (DIR MISSING)'
[ $exitcode -eq $DEPS_NONE ] && echo -e "$SLUG"'\tFAIL (DEPS_NONE)'
[ $exitcode -eq $DEPS_MISMATCH ] && echo -e "$SLUG"'\tFAIL (DEPS_MISMATCH)'

## 137 is SIGKILL for docker containers
[ $exitcode -eq 137 ] && echo -e "$SLUG"'\tFAIL (DOCKER KILL)'
[ $exitcode -eq 0 ] && echo -e "$SLUG"'\tSUCCESS'