#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys

###            [0]         [1]               [2]
### python3 filter.py <classes.txt>  <callsites.txt>
###

classes = set(line.strip() for line in open(sys.argv[1]))

dependency_callsites = list()

for line in open(sys.argv[2]):
    signature = line.split(",")
    if signature[0] in classes:
        dependency_callsites.append("/".join(signature))



with open('CALLSITES', 'w') as f:
    for cs in dependency_callsites:
        f.write("%s" % cs)
