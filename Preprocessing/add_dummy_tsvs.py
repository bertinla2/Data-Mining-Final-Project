#!/usr/bin/env python3
"""
Add dummy *_bold.tsv files to each subject's func directory by copying
them from a source subject (default: sub-331) and renaming to the target
subject's label.

Usage:
  python add_dummy_tsvs.py --root /scratch/lbertin/Bids_test --src sub-331 --dry-run
  python add_dummy_tsvs.py --root /scratch/lbertin/Bids_test --src sub-331

Notes:
- Expects the source dummy files to live at: <root>/<src>/func/*.tsv
- Only copies files matching '^sub-<ID>.*_bold.tsv$'
- For each target subject <tgt> with <root>/<tgt>/func/:
    - If a same-named TSV already exists, it is skipped.
    - Otherwise a copy is made with the subject prefix changed from
      ^sub-<srcID> to ^sub-<tgtID> (the rest of the filename is kept).
"""

from pathlib import Path
import shutil
import re
import argparse
import sys

SUB_PREFIX_RE = re.compile(r'^sub-\w+')  # replace only the subject prefix at start

def find_source_tsvs(root: Path, src_subject: str):
    src_func = root / src_subject / 'func'
    if not src_func.is_dir():
        sys.exit(f"[ERROR] Source func directory not found: {src_func}")
    tsvs = sorted(p for p in src_func.glob('*.tsv') if re.match(rf'^{re.escape(src_subject)}.*_bold\.tsv$', p.name))
    if not tsvs:
        sys.exit(f"[ERROR] No source TSVs matching pattern '{src_subject}*_bold.tsv' found in {src_func}")
    return tsvs

def iter_target_subjects(root: Path):
    for p in sorted(root.glob('sub-*')):
        if p.is_dir():
            yield p.name

def main():
    ap = argparse.ArgumentParser(description="Copy dummy *_bold.tsv files into each subject's func directory.")
    ap.add_argument('--root', type=str, default='/scratch/lbertin/Bids_test', help='BIDS root containing sub-*/ directories')
    ap.add_argument('--src', type=str, default='sub-331', help='Source subject label that already has the dummy TSVs')
    ap.add_argument('--dry-run', action='store_true', help='Print actions without copying files')
    args = ap.parse_args()

    root = Path(args.root).resolve()
    src_subject = args.src

    print(f"[INFO] BIDS root: {root}")
    print(f"[INFO] Source subject: {src_subject}")
    tsvs = find_source_tsvs(root, src_subject)
    print(f"[INFO] Found {len(tsvs)} source TSV(s):")
    for t in tsvs:
        print(f"       - {t.name}")

    total_copied = 0
    total_skipped = 0
    total_missing_func = 0

    for tgt_subject in iter_target_subjects(root):
        # Skip the source itself; it already has dummy TSVs
        if tgt_subject == src_subject:
            continue

        tgt_func = root / tgt_subject / 'func'
        if not tgt_func.is_dir():
            print(f"[WARN] {tgt_subject}: no func directory -> skipping")
            total_missing_func += 1
            continue

        print(f"[INFO] Processing {tgt_subject} ...")
        for src_file in tsvs:
            # Create new filename by swapping the subject prefix at the start of the name
            new_name = SUB_PREFIX_RE.sub(tgt_subject, src_file.name, count=1)
            dest = tgt_func / new_name

            if dest.exists():
                print(f"   - {dest.name} already exists -> skip")
                total_skipped += 1
                continue

            print(f"   - copy {src_file.name}  ->  {dest.name}")
            if not args.dry_run:
                try:
                    shutil.copy2(src_file, dest)
                except Exception as e:
                    print(f"     [ERROR] copy failed: {e}")
                else:
                    total_copied += 1

    print("\n[SUMMARY]")
    print(f"  Copied : {total_copied}")
    print(f"  Skipped: {total_skipped} (already existed)")
    print(f"  No func dir: {total_missing_func} subjects")

if __name__ == '__main__':
    main()
