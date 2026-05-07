#!/usr/bin/env python3
import argparse
from pathlib import Path

# List of expected files (patterns where {sub} is replaced by subject ID)
EXPECTED_FILES = [
    "{sub}_ses-02_task-BT_run-01_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz",
    "{sub}_ses-02_task-BT_run-02_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz",
    "{sub}_ses-02_task-BT_run-01_desc-confounds_timeseries.tsv",
    "{sub}_ses-02_task-BT_run-02_desc-confounds_timeseries.tsv"
]

def format_size(bytes_size):
    """Return size in MB with two decimal places."""
    return f"{bytes_size / (1024 * 1024):.2f} MB"

def main():

    bids_dir = Path("/scratch/lbertin/Bids_test")
    derivs_dir = bids_dir / "derivatives"

    subjects = sorted([p.name for p in bids_dir.glob("sub-*") if p.is_dir()])
    if not subjects:
        print("No subjects found under", bids_dir)
        return

    print("Subject\tFile\tSize")
    for sub in subjects:
        func_dir = derivs_dir / sub / "ses-02" / "func"

        for template in EXPECTED_FILES:
            filename = template.format(sub=sub)
            file_path = func_dir / filename

            if file_path.exists():
                size_bytes = file_path.stat().st_size
                print(f"{sub}\t{filename}\t{format_size(size_bytes)}")
            else:
                print(f"{sub}\t{filename}\tMISSING")

if __name__ == "__main__":
    main()
