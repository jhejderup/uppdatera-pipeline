#!/bin/bash

##
## ./fix_pitest_args.sh <path>/pitest.log <path>/args.pit 
##

### Two scenarios: 
### no exclusion -> add new line
### already exlusion -> append the classname 
### --excludedClasses 

PITLOG=$1
PITARGS=$2

###
### Check parameters
###
if [[ ! -f "$PITLOG" || ! -f "$PITARGS" ]]; then
    echo "[uppdatera][fix_pit_args.sh] the input parameters don't exists!"
    exit "$PITARGS_EXCLASS_FILE_FAIL";    
fi

###
### Check if error is missing source file
###
output=$(grep "does not contain source debug information. All classes must have an associated source file"  "$PITLOG")

if [ -n "$output" ]; then
    CLASSNAME=$(echo "$output" | cut -d : -f 2 | sed 's/ The class //' | sed 's/ does not contain source debug information. All classes must have an associated source file//')

    ###
    ### Remove the classname in targetClasses
    ###
    if grep -q "\-\-targetClasses $CLASSNAME" "$PITARGS"
    then 
        echo "[uppdatera][fix_pit_args.sh] no more target classes, send negative exit code!"
        exit "$PITARGS_EXCLASS_FAIL";
    fi

    if grep -q ",$CLASSNAME" "$PITARGS"
    then
        echo "[uppdatera][fix_pit_args.sh] removing <$CLASSNAME,> from targetClasses"
        sed -i "s/,$CLASSNAME//" "$PITARGS"    
    fi

    if grep -q "$CLASSNAME," "$PITARGS"
    then
        sed -i "s/$CLASSNAME,//" "$PITARGS"
        echo "[uppdatera][fix_pit_args.sh] removing <,$CLASSNAME> from targetClasses"
    fi

    ###
    ### Put classname in the exclusion filter
    ###
    if grep -q "\-\-excludedClasses" "$PITARGS"
    then
        echo -n ",$CLASSNAME" >> "$PITARGS"
    else
        echo -n " --excludedClasses $CLASSNAME" >> "$PITARGS"
    fi

    ###
    ### Delete the file directely 
    ###
    find target/classes -path "*${CLASSNAME//./\/}.class" -exec rm -f {} \;
    exit 0;
fi

###
### Check if error are test failures
###
output=$(grep -Enr "Exception in thread \"main\" org\.pitest\.help\.PitHelpError: [[:digit:]]+ tests did not pass without mutation when calculating line coverage\. Mutation testing requires a green suite"   "$PITLOG")

if [ -n "$output" ]; then
    TEST_FILE="$MODULE_DATA_ERR"/failed_tests.txt
    ## Find relevant line numbers
    end_ln=$(echo "$output" | awk -F":" '{print $1}')
    delta=$(python3 /extract_failed_tests.py "$output")
    start_ln=$((end_ln-delta))
    
    ## Save segmemnt to file
    sed -n "$start_ln,$((end_ln-1))p;$((end_ln))q" "$PITLOG" > "$TEST_FILE"
    ## Create arguments
    echo -n "$(python3 /parse_failed_tests.py "$TEST_FILE")" >> "$PITARGS"
    exit 0;
fi

exit "$PITARGS_EXCLASS_FILE_FAIL"; 
