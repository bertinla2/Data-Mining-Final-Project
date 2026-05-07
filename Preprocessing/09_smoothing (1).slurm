#!/bin/bash
#SBATCH --job-name=SMOOTHING
#SBATCH --array=0-120%4
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --constraint=intel
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

set -Eeuo pipefail

module purge
module load hosts/hopper
module load ohpc
module load matlab

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export MKL_NUM_THREADS=$SLURM_CPUS_PER_TASK

matlab -nodisplay -r "run('/scratch/lbertin/ParSmoothing.m'); exit;"
