#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys
from pathlib import Path

###
### VARIABLES (& ASSERT)
###
src_file = os.environ['SRC_DEP_FILE']
src_folder = os.environ['SRC_JAR_DIR']

bin_file = os.environ['BIN_DEP_FILE']
bin_folder = os.environ['JAR_DIR']


assert os.path.isfile(src_file)
assert os.path.isfile(bin_file)

assert os.path.isdir(src_folder)
assert os.path.isdir(bin_folder)

###
### Parse dependency information into KV pairs
###  [jar] -> [coord] -> [source-jar] 
sources = {}
inv_sources = {}
with open(src_file, 'r') as fh:
    for line in fh:
        if ":/" in line:
            line = line.rstrip("\n").replace(" ", "").replace(":jar:sources","")
            jarcoord = line.split(":/")
            jar_filename = os.path.basename(jarcoord[1])
            if Path(os.path.join(src_folder, jar_filename)).exists():
                sources[jarcoord[0]] = jar_filename
                inv_sources[jar_filename] = jarcoord[0]

binaries = {}
inv_binaries = {}
with open(bin_file, 'r') as fh:
    for line in fh:
        if ":/" in line:
            line = line.rstrip("\n").replace(" ", "").replace(":jar","")
            jarcoord = line.split(":/")
            jar_filename = os.path.basename(jarcoord[1])
            if Path(os.path.join(bin_folder, jar_filename)).exists():            
                binaries[jar_filename] = jarcoord[0]
                inv_binaries[jarcoord[0]] = jar_filename


### If there are no dependencies; we exit!
if not bool(binaries) or not bool(sources):
    sys.exit(int(os.environ['DEPS_NONE']))




### Process bin folder 
for filename in os.listdir(bin_folder):
    if filename.endswith(".jar") and filename in binaries:
        coord = binaries[filename]
        if coord in sources:
            print("[Uppdatera][KEEP][" + sys.argv[0] +"]["+ coord+"] " + os.path.join(bin_folder, filename))
            continue
        else:
            print("[Uppdatera][DEL][" + sys.argv[0] +"]["+ coord+"] " + os.path.join(bin_folder, filename))
            os.remove(os.path.join(bin_folder, filename))
    else:
        print("[Uppdatera][DEL][" + sys.argv[0] +"] " + os.path.join(bin_folder, filename))
        os.remove(os.path.join(bin_folder, filename))
        continue

### Process src folder
for filename in os.listdir(src_folder):
    if filename.endswith(".jar") and filename in inv_sources:
        coord = inv_sources[filename]
        if coord in inv_binaries:
            print("[Uppdatera][KEEP][" + sys.argv[0] +"][src-jar]["+ coord+"]  " + os.path.join(src_folder, filename))
            continue
        else:
            print("[Uppdatera][DEL][" + sys.argv[0] +"][src-jar]["+ coord+"]  " + os.path.join(src_folder, filename))
            os.remove(os.path.join(src_folder, filename))
    else:
        print("[Uppdatera][DEL][" + sys.argv[0] +"] " + os.path.join(src_folder, filename))
        os.remove(os.path.join(src_folder, filename))
        continue

### Check if number of dependencies match
def count_files(dir):
    return len([1 for x in list(os.scandir(dir)) if x.is_file()])

src_jars = count_files(src_folder)
jars = count_files(bin_folder)

if src_jars is not jars:
    print("[Uppdatera][" + sys.argv[0] +"] jar-count ("+str(jars)+") != ("+str(src_jars)+") src-jar count")
    sys.exit(int(os.environ['DEPS_MISMATCH']))
else:
    print("[Uppdatera][" + sys.argv[0] +"] jar-count ("+str(jars)+") == ("+str(src_jars)+") src-jar count")    

sys.exit(0)
