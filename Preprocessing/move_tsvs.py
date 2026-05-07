import os
import shutil
import glob

# Base directories
derivatives_base = "/scratch/lbertin/Bids_test/derivatives"
smoothed_base = "/scratch/lbertin/Bids_test/smoothed"

# Get all subject folders in derivatives
subjects = sorted(glob.glob(os.path.join(derivatives_base, "sub-*")))

for subj_path in subjects:
    subj_id = os.path.basename(subj_path)
    
    func_dir = os.path.join(subj_path, "ses-02", "func")
    
    if not os.path.isdir(func_dir):
        print(f"Skipping {subj_id}: func directory not found")
        continue
    
    # Find all .tsv files
    tsv_files = glob.glob(os.path.join(func_dir, "*.tsv"))
    
    if len(tsv_files) == 0:
        print(f"No .tsv files found for {subj_id}")
        continue
    
    # Destination directory
    dest_dir = os.path.join(smoothed_base, subj_id)
    os.makedirs(dest_dir, exist_ok=True)
    
    for tsv_file in tsv_files:
        dest_file = os.path.join(dest_dir, os.path.basename(tsv_file))
        
        print(f"Moving {tsv_file} ? {dest_file}")
        shutil.move(tsv_file, dest_file)

print("Done.")