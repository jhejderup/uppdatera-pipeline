#!/usr/bin/env python

import sys


###
### recall.py dynamic.txt static.txt
###

if len(sys.argv) != 3:
    print("only two text file arguments!")
    sys.exit(2)



dyn_lst = [line for line in open(sys.argv[1]) if line.startswith("L")]
dyn_set = set(dyn_lst)




