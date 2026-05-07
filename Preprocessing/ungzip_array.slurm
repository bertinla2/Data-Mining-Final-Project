#!/bin/bash
#SBATCH --job-name=UNGZIP
#SBATCH --time=1-16:00:00
#SBATCH --array=0-130%4
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4G
#SBATCH --constraint=intel
#SBATCH --partition=normal
#SBATCH --qos=normal
#SBATCH --output=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.out
#SBATCH --error=/scratch/lbertin/SLURM_output/%x-%N-%A-%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=lbertin@gmu.edu

# ---- Robust bash settings ----
set -Eeuo pipefail

# ---- Ensure log directory exists and capture EVERYTHING to a task log ----
LOG_ROOT="/scratch/lbertin/SLURM_output"
mkdir -p "$LOG_ROOT"

TASK_LOG="${LOG_ROOT}/${SLURM_JOB_NAME:-job}-${SLURM_JOB_ID:-noid}-${SLURM_ARRAY_TASK_ID:-x}.log"

# Pretty xtrace timestamps
export PS4='+ ${EPOCHREALTIME-$(date +%s.%N)} ${BASH_SOURCE##*/}:${LINENO}: '


# Send both stdout and stderr to the task log (and still to Slurm files)
exec > >(tee -a "$TASK_LOG") 2>&1
set -x  # start command tracing after tee is attached

# Error trap that leaves a clear message in the log
on_err() {
  local ec=$?
  echo ""
  echo "================= ERROR TRAP ================="
  echo "JobID: ${SLURM_JOB_ID:-unknown}  TaskID: ${SLURM_ARRAY_TASK_ID:-NA}"
  echo "Node : ${HOSTNAME:-unknown}  Time: $(date -Is)"
  echo "Script failed with exit code: $ec"
  echo "See log: $TASK_LOG"
  echo "=============================================="
  exit $ec
}
trap on_err ERR

echo "Started: $(date -Is)"
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-}"
echo "SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID:-}"
echo "SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-1}"
echo "HOSTNAME=${HOSTNAME:-}"

# ---- Paths (edit if needed) ----
BASE_DIR="/scratch/lbertin/Bids_test/derivatives"
REL1="ses-02/func/sub-XXX_ses-02_task-BT_run-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz"
REL2="ses-02/func/sub-XXX_ses-02_task-BT_run-02_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz"

# If you have environment modules and pigz is a module, uncomment:
# module load pigz || true

# ---- Find subjects ----
if [[ ! -d "$BASE_DIR" ]]; then
  echo "FATAL: BASE_DIR does not exist: $BASE_DIR"
  exit 2
fi

mapfile -t SUBS < <(find "$BASE_DIR" -maxdepth 1 -type d -name "sub-*" | sort)
NUM_SUBS="${#SUBS[@]}"
echo "Discovered ${NUM_SUBS} subject dirs under ${BASE_DIR}"

if (( NUM_SUBS == 0 )); then
  echo "FATAL: No subject directories (sub-*) found."
  exit 3
fi

# Handle array larger than subject count
if (( SLURM_ARRAY_TASK_ID >= NUM_SUBS )); then
  echo "Array index ${SLURM_ARRAY_TASK_ID} >= num subjects ${NUM_SUBS}; nothing to do."
  exit 0
fi

SUB_DIR="${SUBS[$SLURM_ARRAY_TASK_ID]}"
SUB_ID="$(basename "$SUB_DIR")"
echo "Working on subject: ${SUB_ID}"
echo "Subject directory:  ${SUB_DIR}"

# ---- Decompress helper (keeps .gz) ----
decompress_keep_gz () {
  local gzpath="$1"
  local outpath="${gzpath%.gz}"

  echo "Check: $gzpath"
  if [[ ! -f "$gzpath" ]]; then
    echo "WARN: missing $gzpath (skipping)"
    return 0
  fi

  if [[ -f "$outpath" ]]; then
    echo "SKIP: already exists $outpath"
    return 0
  fi

  if command -v pigz >/dev/null 2>&1; then
    pigz -d -k -p "${SLURM_CPUS_PER_TASK:-1}" "$gzpath"
  else
    gzip -dc "$gzpath" > "$outpath"
  fi

  if [[ ! -s "$outpath" ]]; then
    echo "FATAL: output empty or missing after decompress: $outpath"
    return 4
  fi

  echo "OK: $(basename "$gzpath") -> $(basename "$outpath")"
}

# ---- Resolve file paths for this subject ----
REL1_SUB="${REL1//sub-XXX/$SUB_ID}"
REL2_SUB="${REL2//sub-XXX/$SUB_ID}"
F1="$SUB_DIR/$REL1_SUB"
F2="$SUB_DIR/$REL2_SUB"

echo "Target files:"
echo "  F1: $F1"
echo "  F2: $F2"

# ---- Decompress the two files ----
decompress_keep_gz "$F1"
decompress_keep_gz "$F2"

echo "Finished subject ${SUB_ID} at $(date -Is)"
