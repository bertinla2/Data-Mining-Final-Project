#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Scan /scratch/lbertin/Bids_test/smoothed/sub-### for confounds .tsv files and
report runs with >= 30% motion outliers.

Outlier columns handled (any of these):
  - motion_outlier00, motion_outlier01, ...
  - non_steady_state_outlier00, ...
  - motion_correction00, ...   (kept for compatibility with your earlier description)

Frames = number of data rows (exclude header).
Outliers = number of outlier indicator columns present in header.
"""

import re
import csv
from pathlib import Path
from typing import Dict, Optional, Tuple, List

SMOOTHED_ROOT = Path("/scratch/lbertin/Bids_test/smoothed")

# Accept several common fMRIPrep-style names.
OUTLIER_PATTERNS = [
    re.compile(r"^motion[_]?outlier\d+$"),
    re.compile(r"^non_steady_state_outlier\d+$"),
    re.compile(r"^motion[_]?correction\d+$"),
]

RUN_RE = re.compile(r"run-(\d{2})")

def is_outlier_col(name: str) -> bool:
    return any(p.match(name) for p in OUTLIER_PATTERNS)

def parse_subject_and_run(tsv_path: Path) -> Tuple[str, str]:
    sub_id = tsv_path.parent.name  # e.g., 'sub-001'
    m = RUN_RE.search(tsv_path.name)
    run = m.group(1) if m else ""
    return sub_id, run

def analyze_confounds_tsv(tsv_path: Path) -> Optional[Dict]:
    try:
        with tsv_path.open("r", newline="") as f:
            reader = csv.reader(f, delimiter="\t")
            header = next(reader, None)
            if not header:
                return None

            outlier_cols: List[str] = [c for c in header if is_outlier_col(c)]
            outlier_count = len(outlier_cols)

            # Count frames (rows excluding header).
            frame_count = sum(1 for _ in reader)

        pct = (outlier_count / frame_count) if frame_count > 0 else 0.0
        return {
            "path": str(tsv_path),
            "frames": frame_count,
            "outliers": outlier_count,
            "pct_outliers": pct,
            "outlier_cols": outlier_cols[:],  # keep for optional diagnostics
        }
    except Exception as e:
        print(f"[ERROR] Failed to read {tsv_path}: {e}")
        return None

def main():
    if not SMOOTHED_ROOT.exists():
        print(f"[ERROR] Smoothed root not found: {SMOOTHED_ROOT}")
        return

    results = []
    subjects = sorted([p for p in SMOOTHED_ROOT.iterdir() if p.is_dir() and p.name.startswith("sub-")])

    if not subjects:
        print(f"[INFO] No subject folders found under {SMOOTHED_ROOT}")
        return

    print(f"[INFO] Found {len(subjects)} subject(s) under {SMOOTHED_ROOT}")

    for sdir in subjects:
        tsvs = sorted(sdir.glob("*_desc-confounds_timeseries.tsv"))
        if not tsvs:
            print(f"[WARN] {sdir.name}: no confounds .tsv files found")
            continue

        for tsv in tsvs:
            sub_id, run = parse_subject_and_run(tsv)
            summary = analyze_confounds_tsv(tsv)
            if summary is None:
                print(f"[WARN] {sub_id} run-{run or '??'}: could not analyze {tsv.name}")
                continue

            # Lightweight diagnostic if zero found
            if summary["outliers"] == 0:
                try:
                    with tsv.open("r", newline="") as f:
                        reader = csv.reader(f, delimiter="\t")
                        header = next(reader, [])
                    sample = ", ".join(header[:20])
                    print(f"[DIAG] {sub_id} run-{run or '??'}: 0 outlier columns detected. "
                          f"First 20 header fields: {sample}")
                except Exception:
                    pass

            results.append({
                "subject": sub_id,
                "run": run or "",
                "frames": summary["frames"],
                "outliers": summary["outliers"],
                "pct_outliers": summary["pct_outliers"],
                "path": summary["path"],
            })

    if not results:
        print("[INFO] No results to report.")
        return

    # Pretty print per-run summary
    print("\n=== Motion Outlier Summary (per run) ===")
    print("subject\trun\tframes\toutliers\tpct_outliers\tflag_ge_30pct")
    flagged = []
    for r in sorted(results, key=lambda x: (x["subject"], x["run"])):
        pct = r["pct_outliers"]
        flag = pct >= 0.30
        line = f"{r['subject']}\t{r['run']}\t{r['frames']}\t{r['outliers']}\t{pct:.3f}\t{flag}"
        print(line)
        if flag:
            flagged.append(r)

    print("\n=== Runs with >= 30% motion outliers ===")
    if flagged:
        for r in flagged:
            print(f"- {r['subject']} run-{r['run']}: {r['outliers']}/{r['frames']} "
                  f"({r['pct_outliers']*100:.1f}%)  [{r['path']}]")
    else:
        print("None.")

if __name__ == "__main__":
    main()
