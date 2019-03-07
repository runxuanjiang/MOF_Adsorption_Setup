#!/bin/bash

cat EDUSIF_clean_min_charges.cif | grep -Pzo '.*atom_site_charge(.*\n)*' | sed '1d' > cut_cif.dat
sed -e s/atom_site_charge//g cut_cif.dat | awk '{print $1}' | sort | uniq > uniqatoms.dat
cat uniqatoms.dat

#works up to here so far...
uniqatoms=( $( cat uniqatoms.dat) )
replacement_list=( $(cat replacement_names.dat) )
atom_total=$( echo ${#uniqatoms[@]} )
setup_id=1
until [ ${setup_id} -gt ${atom_total} ]; do
	atom_name=${uniqatoms[$setup_id - 1]}
	replacement_name=${replacement_list[$setup_id - 1]}
	echo "now setting up atom $atom_name"
	echo "replacing to $replacement_name"
	echo "this is atom number $setup_id"
	sed -i "s/$atom_name/$replacement_name/g" *charges.cif
	setup_id=$(($setup_id + 1))
	
done
python extend_unit_cell.py

setup_id=1
until [ ${setup_id} -gt ${atom_total} ]; do
	atom_name=${uniqatoms[$setup_id - 1]}
	replacement_name=${replacement_list[$setup_id - 1]}
	sed -i "s/$replacement_name/$atom_name/g" *.pdb
	setup_id=$(($setup_id + 1))
done

vmd < convert_Pymatgen_PDB.tcl *.pdb
