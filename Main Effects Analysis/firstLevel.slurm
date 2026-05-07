#!/bin/bash
#SBATCH --job-name=FIRSTLEVEL
#SBATCH --array=1-2%2
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

module load matlab/r2023a
mkdir -p /scratch/lbertin/SLURM_output

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export MKL_NUM_THREADS=$SLURM_CPUS_PER_TASK

# ==========================
# HARD-CODED SUBJECT LIST
# ==========================
#subjects=(sub-331 sub-332 sub-336 sub-338 sub-339 sub-340 sub-341 sub-342 sub-343 sub-344 sub-345 sub-346 sub-347 sub-348 sub-349 sub-350 sub-351 sub-352 sub-353 sub-354 sub-356 sub-357 sub-359 sub-360 sub-361 sub-363 sub-364 sub-365 sub-368 sub-369
#sub-370 sub-399 sub-400 sub-402 sub-404 sub-405 sub-406 sub-407 sub-408 sub-409 sub-410 sub-411 sub-412 sub-413 sub-414 sub-416 sub-417 sub-419 sub-420 sub-421 sub-422 sub-423 sub-424 sub-425 sub-426 sub-428 sub-429 sub-430 sub-431 sub-432
#sub-433 sub-471 sub-473 sub-476 sub-477 sub-478 sub-479 sub-480 sub-482 sub-484 sub-485 sub-486 sub-487 sub-488 sub-489 sub-491 sub-493 sub-519 sub-526 sub-527 sub-529)
subjects=(sub-426)

nsubs=${#subjects[@]}
echo "Total subjects: $nsubs"

task=${SLURM_ARRAY_TASK_ID}

if (( task < 1 || task > nsubs )); then
  echo "INFO: SLURM_ARRAY_TASK_ID=${task} out of range (1..${nsubs}). Exiting."
  exit 0
fi

subj="${subjects[$((task-1))]}"
echo "Running subject: ${subj}  (task ${task}/${nsubs})"

# ==========================
# PASS SUBJECT TO MATLAB
# ==========================
export SUBJECT_ID=${subj}

matlab -nodisplay -nosplash -r "run('/scratch/lbertin/FirstLevelNewStickEarly.m');"