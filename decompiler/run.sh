#!/usr/bin/env bash

###
###  ONLY STDIN/STDOUT
###  docker run -i uppdatera-decompiler < CLASSFILE 
###
cat > content.class
java -jar "$DECOMP"/procyon-decompiler.jar content.class
