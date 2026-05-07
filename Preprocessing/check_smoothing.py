import os
import glob

smoothed_base = "/scratch/lbertin/Bids_test/smoothed"

# Get all subject folders
subjects = sorted(glob.glob(os.path.join(smoothed_base, "sub-*")))

print("\n===== Checking Smoothed Directory =====\n")

for subj_path in subjects:
    subj_id = os.path.basename(subj_path)
    print(f"\n--- {subj_id} ---")

    # -----------------------
    # Check TSV files
    # -----------------------
    tsv_pattern = os.path.join(
        subj_path,
        f"{subj_id}_ses-02_task-BT_run-*_desc-confounds_timeseries.tsv"
    )
    tsv_files = sorted(glob.glob(tsv_pattern))

    if len(tsv_files) == 2:
        print("TSV files: ? 2 found")
    else:
        print(f"TSV files: ? Expected 2, found {len(tsv_files)}")

    # -----------------------
    # Check smoothed NIfTI files
    # -----------------------
    nii_pattern = os.path.join(
        subj_path,
        f"smoothed8_{subj_id}_ses-02_task-BT_run-*_space-MNI152NLin2009cAsym_desc-preproc_bold.nii"
    )
    nii_files = sorted(glob.glob(nii_pattern))

    if len(nii_files) == 2:
        print("Smoothed NIfTI files: ? 2 found")
    else:
        print(f"Smoothed NIfTI files: ? Expected 2, found {len(nii_files)}")

    # -----------------------
    # Print file sizes
    # -----------------------
    for nii_file in nii_files:
        size_bytes = os.path.getsize(nii_file)
        size_mb = size_bytes / (1024 * 1024)
        print(f"   {os.path.basename(nii_file)}")
        print(f"      Size: {size_mb:.2f} MB")

print("\nDone.\n")