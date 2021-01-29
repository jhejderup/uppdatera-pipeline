#!/usr/bin/env bash

###  HOW TO RUN
###     cat ../../data.csv | awk -F "," '{print "./run.sh /data/ght_uppdatera " $2 " "  $3 " "  $4 " " $5 " " $6 " " $7 " " $8}' > cmds.txt
###     cat cmds.txt | paralllel -j30 > results.txt
###     time cat cmds.txt | parallel -j30  > uppdgh-run-11jan.txt


###
### ARGS
###
DIR=$1
PR_NUMBER=$2
PR_URL=$3
PR_TITLE=$4
PR_STATE=$5
SLUG=$6
SHA=$7
POM_PATH=$8
GROUPID=$9
ARTIFACTID=${10}
OLD_VER=${11}
NEW_VER=${12}

###
### EXIT CODES
###
GIT_ERR=1
MVN_INSTALL_ERR=2
MISSING_ARG=3
DIR_NOT_FOUND=4
DEPS_NONE=5
DEPS_MISMATCH=6
PATH_NOT_EXIST=7
CLASSES_NOT_EXIST=8
ANALYSIS_FAIL=9
NO_REPORT_FILE=10

### UPPD
UPPD_ART=50
UPPD_CP_INCORR=51
UPPD_NO_AFFECT_CHANGES=52
###
### CREATE DIR
###

OLD_VER_N="${OLD_VER//./_}"
NEW_VER_N="${NEW_VER//./_}"
GID_N="${GROUPID//./_}"
AID_N="${ARTIFACTID//./_}"

MOUNT_DIR="$DIR/$SLUG/$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"
mkdir -p "$MOUNT_DIR"

###
### RUN CG GENERATION
###
docker run --rm -v "$MOUNT_DIR":/data uppdatera "$SLUG" "$SHA" "$POM_PATH" "$GROUPID" "$ARTIFACTID" "$OLD_VER" "$NEW_VER" "$PR_NUMBER" "$PR_URL" "$PR_TITLE" &> "$MOUNT_DIR"/docker.log
exitcode=$?

###
### CHECK EXIT CODE
###
[ $exitcode -eq $GIT_ERR ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (GIT/UPPD)'
[ $exitcode -eq $MVN_INSTALL_ERR ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (MVN INSTALL)'
[ $exitcode -eq $MISSING_ARG ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (ARG MISSING)'
[ $exitcode -eq $DIR_NOT_FOUND ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (DIR MISSING)'
[ $exitcode -eq $DEPS_NONE ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (DEPS NONE)'
[ $exitcode -eq $DEPS_MISMATCH ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (DEPS MISMATCH)'
[ $exitcode -eq $PATH_NOT_EXIST ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (INVALID PATH IN PR)'
[ $exitcode -eq $CLASSES_NOT_EXIST ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (NO TARGET CLASSES)'
[ $exitcode -eq $ANALYSIS_FAIL ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (ANALYSIS FAIL)'
[ $exitcode -eq $NO_REPORT_FILE ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (NO REPORT FILE)'
[ $exitcode -eq $UPPD_ART ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (ARTIFACT RESOLV ERROR)'
[ $exitcode -eq $UPPD_CP_INCORR ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (CP ERROR)'
[ $exitcode -eq $UPPD_NO_AFFECT_CHANGES ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tOK (NO AFFECT CHANGES)'
## 137 is SIGKILL for docker containers
[ $exitcode -eq 137 ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tFAIL (DOCKER KILL)'
[ $exitcode -eq 0 ] && echo -e "$PR_URL"'\t'"$SLUG"'\t'"$GID_N-$AID_N-$OLD_VER_N-$NEW_VER_N"'\tSUCCESS'
