#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Instructions
#  python3 pit_args.py <path>/target/test-classes <path>/cha.txt <path>dyn-cg.txt <path>/dep_src_dir
#  output: args.pit
# 
import os, sys

if len(sys.argv) != 5:
    print("[uppdatera]["+sys.argv[0]+"] - missing arguments!")
    sys.exit(int(os.environ['PITARGS_FAIL']))

###
### Read all test-classes
###
test_classes = set()
for root, directories, filenames in os.walk(sys.argv[1]):
    for filename in filenames:
        if filename.endswith(".class"):
            clazzPath = os.path.join(root.replace(sys.argv[1] + "/",""), filename.replace(".class",""))
            test_classes.add(clazzPath.replace("/","."))
            continue
        else:
            continue

###
### Read target classes
###
target_classes = set() 

# 1. Read WALA
with open(sys.argv[2]) as fp:
   for cnt, line in enumerate(fp):
       clazzPath = line.rstrip()
       target_classes.add(os.path.dirname(clazzPath).replace("/",".") + ".*")

# 2. Read Dynamic Call graph
with open(sys.argv[3]) as fp:
   for cnt, line in enumerate(fp):
       cut_half = line.rstrip().split("(") # split at method desc 
       arr = cut_half[0].split("/")
       arr.pop() # remove last element (method segment)
       arr.pop() # remove last element (class segment)
       arr.append("*")
       arr[0] = arr[0][1:] ##Remove 'L' in beginning 
       target_classes.add(".".join(arr))

pit_folder = os.environ['PIT_DATA']

###
### Get all source folders
###
srcs = set()
for x in os.listdir(sys.argv[4]):
    srcs.add(os.path.join(sys.argv[4],x))

###
### Save PIT ARGS to file
###
with open(pit_folder + "/args.pit", 'w') as file:
    file.write(" --targetClasses " + ','.join(target_classes) + 
      " --reportDir " + pit_folder +
      " --sourceDirs src/main/java,src/main/test," + ','.join(srcs) + 
      " --targetTests " + ','.join(test_classes) +
      " --outputFormats=CSV" +
      " --threads=4" +
      " --features=+EXPORT" +
      " --timestampedReports=false")

sys.exit(0)
