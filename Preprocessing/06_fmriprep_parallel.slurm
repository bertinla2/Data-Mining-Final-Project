#!/bin/bash

#SBATCH --job-name=fmriprep_hh
#SBATCH --time=1-16:00:00
#SBATCH --array=0-130%4  # Set the array range to 1-x where x is the number of participants to process concurrently
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --constraint=intel
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

set -euo pipefail

STUDY=/scratch/lbertin
BIDS_DIR="${STUDY}/Bids_test"
DERIVS_DIR="${BIDS_DIR}/derivatives"
WORK_DIR="${STUDY}/work_fmriprep"

TEMPLATEFLOW_HOST_HOME="${STUDY}/.cache/templateflow"
FMRIPREP_HOST_CACHE="${STUDY}/.cache/fmriprep"
mkdir -p "${TEMPLATEFLOW_HOST_HOME}" "${FMRIPREP_HOST_CACHE}" "${DERIVS_DIR}" "${WORK_DIR}" "${STUDY}/SLURM_output"

module load singularity

# Build subject list of those NOT already processed
mapfile -t ALL_SUBJECT_DIRS < <(ls -d "${BIDS_DIR}"/sub-* 2>/dev/null || true)
PROCESS_SUBJECTS=()
for dir in "${ALL_SUBJECT_DIRS[@]}"; do
  subject="${dir##*/}"
  if [[ ! -d "${DERIVS_DIR}/fmriprep/${subject}" ]]; then
    PROCESS_SUBJECTS+=("$subject")
  fi
done

NUM_SUBJECTS=${#PROCESS_SUBJECTS[@]}
echo "Subjects to process (${NUM_SUBJECTS}): ${PROCESS_SUBJECTS[*]}"
if (( NUM_SUBJECTS == 0 )); then
  echo "No new subjects to process."
  exit 0
fi

if (( SLURM_ARRAY_TASK_ID >= NUM_SUBJECTS )); then
  echo "No subject assigned to array index ${SLURM_ARRAY_TASK_ID}; exiting."
  exit 0
fi

subject="${PROCESS_SUBJECTS[$SLURM_ARRAY_TASK_ID]}"
PART_LABEL="${subject#sub-}"
echo "Processing subject: ${subject} (participant-label ${PART_LABEL})"

LOCKDIR="${DERIVS_DIR}/.locks"
mkdir -p "${LOCKDIR}"
if ! mkdir "${LOCKDIR}/${subject}" 2>/dev/null; then
  echo "Lock exists for ${subject}; another job is processing it. Exiting."
  exit 0
fi
trap 'rmdir "${LOCKDIR}/${subject}" || true' EXIT

rm -f "${DERIVS_DIR}/sourcedata/freesurfer/${subject}/scripts"/IsRunning.* 2>/dev/null || true

SINGULARITY_CMD=(
  singularity run --cleanenv
  -B "${BIDS_DIR}:/data"
  -B "${TEMPLATEFLOW_HOST_HOME}:/templateflow"
  -B "${WORK_DIR}:/work"
  -B "/home/lbertin/license.txt:/opt/freesurfer/license.txt"
  /scratch/lbertin/fmriprep_25.1.4.sif
)

cmd=(
  "${SINGULARITY_CMD[@]}"
  /data /data/derivatives
  participant --participant-label "${PART_LABEL}" -vv
  --omp-nthreads 8 --nprocs 8 --mem-mb 64000
  --output-spaces MNI152NLin2009cAsym anat fsaverage
  --skip-bids-validation
  --use-syn-sdc
  -w /work
)

logfile="/scratch/lbertin/SLURM_output/${SLURM_JOB_NAME}-${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}-${subject}.log"
echo "Commandline: ${cmd[*]}" | tee -a "$logfile"
"${cmd[@]}" 2>&1 | tee -a "$logfile"
exitcode=${PIPESTATUS[0]}

sleep $(( 10 + (RANDOM % 20) ))
echo -e "${subject}\t${SLURM_ARRAY_TASK_ID}\t${exitcode}" >> /scratch/lbertin/fmri_pipeline/${SLURM_JOB_NAME}.tsv
echo "Finished task ${SLURM_JOB_NAME} for ${subject} with exit code ${exitcode}"

exit ${exitcode}