#!/usr/bin/env python
import re,sys,os

###
### python3 /extract_failed_tests <line_of_text>
### output: number 

regex = r"Exception in thread \"main\" org\.pitest\.help\.PitHelpError: (\d+) tests did not pass without mutation when calculating line coverage\. Mutation testing requires a green suite\."

m = re.search(regex, sys.argv[1])
if m:
    sys.stdout.write( m.group(1))
    sys.exit(0)
