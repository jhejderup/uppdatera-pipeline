#!/usr/bin/env python
import re,sys

regex = r"Description \[testClass=(.*), name=(.*)\]"

lines = [line.rstrip('\n') for line in open(sys.argv[1])]

testClasses = set()

for l in lines:
    m = re.search(regex, l)
    if m:
        testClasses.add(m.group(1))


sys.stdout.write(" --excludedTestClasses " + ",".join(testClasses))