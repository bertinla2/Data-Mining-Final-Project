#!/bin/bash
#SBATCH --job-name=GroupMask
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --constraint=intel
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

# Load MATLAB module
module load matlab/r2023a  # Adapt MATLAB version if necessary

# Execute the MATLAB script

matlab -nodisplay -r "run('/scratch/lbertin/MakeGroupMask.m'); exit;"
