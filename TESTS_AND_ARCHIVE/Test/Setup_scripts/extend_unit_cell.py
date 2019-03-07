from pymatgen import Lattice, Structure, Molecule
import openbabel

#pymatgen
structure = Structure.from_file("FILEFILE")
structure.make_supercell([CCC, CCC, CCC])
structure.to(filename="MMMMMM_CCCXCCCXCCC.cif")

#openbabel
obConversion = openbabel.OBConversion()
obConversion.SetInAndOutFormats("cif", "pdb")
mol = openbabel.OBMol()
obConversion.ReadFile(mol, "MMMMMM_CCCXCCCXCCC.cif")
obConversion.WriteFile(mol, 'MMMMMM_clean_min.pdb')
