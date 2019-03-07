#!/bin/bash

for f in $( ls ~/Desktop/minimized_structures_with_DDEC_charges/*.cif ) ; do

	sed -e '1,24d' $f | awk '{print $1}' | sort | uniq

done


