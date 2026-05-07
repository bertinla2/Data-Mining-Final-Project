#!/bin/bash
#SBATCH --job-name=SECONDLEVEL
#SBATCH --array=1-11%4       
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

module load matlab/r2023a

# Keep MATLAB/SPM from fighting over threads
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export MKL_NUM_THREADS=$SLURM_CPUS_PER_TASK

contrasts=(1 2 3 4 5 6 7 8 9 10 11)

ncons=${#contrasts[@]}
echo "Total contrasts: $ncons"

task=${SLURM_ARRAY_TASK_ID}

if (( task < 1 || task > ncons )); then
  echo "INFO: SLURM_ARRAY_TASK_ID=${task} out of range (1..${ncons}). Exiting."
  exit 0
fi

con="${contrasts[$((task-1))]}"
echo "Running contrast: ${con}  (task ${task}/${ncons})"

export CONTRAST_ID=${con}

matlab -nodisplay -nosplash -r "run('/scratch/lbertin/SecondLevelNew.m');"