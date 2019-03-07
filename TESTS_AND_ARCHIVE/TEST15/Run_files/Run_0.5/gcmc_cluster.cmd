#!/bin/bash
#SBATCH --time=900:00:00
#SBATCH --ntasks=1   # number of processor cores (i.e. tasks)
#SBATCH --nodes=1   # number of nodes
echo Running on host `hostname`
echo Time is `date`


cd /home/runxuan/Desktop/WSU_research/MOF_Build_script/TEST15/Run_files
echo Directory is `pwd`


# Run job
./GOMC_CPU_GCMC in.conf >& out_IRMOF-1_argon_0.5_bar.dat
