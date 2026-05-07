#!/usr/bin/env python3
from pathlib import Path

# Expected basenames (no extension). {sub} will be replaced with the subject ID.
EXPECTED_BASES = [
    "{sub}_ses-02_task-BT_run-01_space-MNI152NLin2009cAsym_desc-preproc_bold",
    "{sub}_ses-02_task-BT_run-02_space-MNI152NLin2009cAsym_desc-preproc_bold",
]

def main():
    # Adjust these if your layout differs
    bids_dir = Path("/scratch/lbertin/Bids_test")
    # fMRIPrep standard: .../derivatives/fmriprep/sub-XX/ses-YY/func
    derivs_dir = bids_dir / "derivatives"

    subjects = sorted([p.name for p in bids_dir.glob("sub-*") if p.is_dir()])
    if not subjects:
        print("No subjects found under", bids_dir)
        return

    print("Subject\tAll_Unzipped_Present\tMissing_or_Gzipped")
    for sub in subjects:
        func_dir = derivs_dir / sub / "ses-02" / "func"
        missing = []

        for tmpl in EXPECTED_BASES:
            base = tmpl.format(sub=sub)
            nii_path = func_dir / f"{base}.nii"
            gz_path  = func_dir / f"{base}.nii.gz"

            nii_exists = nii_path.exists()
            gz_exists  = gz_path.exists()

            if not nii_exists:
                # Only count unzipped as present; if gz exists, note it
                if gz_exists:
                    missing.append(f"{base}.nii (only gzipped present)")
                else:
                    missing.append(f"{base}.nii")

            # Optional: flag odd case where both exist
            # elif gz_exists:
            #     missing.append(f"{base}.nii (both .nii and .nii.gz present)")

        all_ok = len(missing) == 0
        print(f"{sub}\t{all_ok}\t{', '.join(missing) if missing else 'None'}")

if __name__ == "__main__":
    main()
