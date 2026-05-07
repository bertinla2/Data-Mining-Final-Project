% Build group mask on the same grid as your smoothed BOLDs
% Iterates through rootDir/sub-*/... recursively to find BOLD NIfTIs.
% Makes per-subject mask from mean image (background removed), then coverage threshold.

restoredefaultpath;
addpath(genpath('/scratch/lbertin/spm12'));  % adjust if your spm.m is nested
assert(exist('spm_vol','file')==2, 'SPM not on path (spm_vol missing)');

rootDir = '/scratch/lbertin/Bids_test/smoothed';

outMask80  = fullfile(rootDir, 'group_mask_fromBOLD_80pct.nii');
outMask100 = fullfile(rootDir, 'group_mask_fromBOLD_intersection.nii');

coverageThresh = 0.80;   % voxel must be "in brain" for >=80% of subjects
kFrac = 0.20;            % per-subject threshold = kFrac * median(nonzero mean)

% ---- find subject folders ----
subs = dir(fullfile(rootDir, 'sub-*'));
subs = subs([subs.isdir]);

if isempty(subs)
    error('No sub-* folders found in %s', rootDir);
end

% ---- pick reference bold (grid definition) ----
refBold = '';
for i = 1:numel(subs)
    subDir = fullfile(rootDir, subs(i).name);
    refBold = pick_bold_file(subDir);
    if ~isempty(refBold)
        break
    end
end
if isempty(refBold)
    error('Could not find any smoothed8_*desc-preproc_bold.nii under %s', rootDir);
end

Vref = spm_vol(refBold);  % refBold is char
refDim = Vref(1).dim;
refMat = Vref(1).mat;

fprintf('Reference BOLD: %s\n', refBold);
fprintf('Ref dim: [%d %d %d]\n', refDim);

coverageCount = zeros(refDim, 'single');
kept = 0;

for i = 1:numel(subs)
    sub = subs(i).name;
    subDir = fullfile(rootDir, sub);

    bold4D = pick_bold_file(subDir);
    if isempty(bold4D)
        fprintf('Skipping %s (no BOLD found)\n', sub);
        continue
    end

    V = spm_vol(bold4D); % bold4D is char

    % Ensure all subjects are on same grid
    if ~isequal(V(1).dim, refDim) || max(abs(V(1).mat(:) - refMat(:))) > 1e-6
        fprintf('Skipping %s (BOLD grid mismatch)\n', sub);
        continue
    end

    % Mean over time (streaming)
    nT = numel(V);
    Ysum = zeros(refDim, 'double');
    for t = 1:nT
        Ysum = Ysum + double(spm_read_vols(V(t)));
    end
    Ymean = Ysum / nT;

    % Per-subject "brain-ish" mask from mean image
    good = isfinite(Ymean) & (Ymean ~= 0);
    if nnz(good) < 1000
        fprintf('Skipping %s (too few nonzero voxels)\n', sub);
        continue
    end

    med = median(Ymean(good));
    thr = kFrac * med;                % relative threshold
    subjMask = good & (Ymean > thr);  % binary mask

    coverageCount = coverageCount + single(subjMask);
    kept = kept + 1;

    fprintf('%s: using %s | subj voxels=%d | thr=%.4f\n', sub, bold4D, nnz(subjMask), thr);
end

if kept < 5
    error('Only %d subjects contributed. Check your filename pattern and folder layout.', kept);
end

coverageFrac = coverageCount / kept;
mask80  = coverageFrac >= coverageThresh;
mask100 = coverageFrac >= 1.0;

% Write masks
Vout = Vref(1);
Vout.dt = [spm_type('uint8') 0];
Vout.pinfo = [1;0;0];

Vout.fname = outMask80;
spm_write_vol(Vout, uint8(mask80));
fprintf('Wrote: %s (>=%.2f coverage of %d subjects)\n', outMask80, coverageThresh, kept);

Vout.fname = outMask100;
spm_write_vol(Vout, uint8(mask100));
fprintf('Wrote: %s (intersection of %d subjects)\n', outMask100, kept);

fprintf('Voxels in mask(>=%.2f): %d\n', coverageThresh, nnz(mask80));
fprintf('Voxels in intersection: %d\n', nnz(mask100));

% ---------------- local function ----------------
function boldPath = pick_bold_file(subDir)
    % Recursively find smoothed preproc BOLD within a subject folder.
    % Prefer run-01 if present, otherwise run-02, otherwise first match.
    % Returns a CHAR path, or '' if not found (SPM-friendly).

    boldPath = '';

    d = dir(fullfile(subDir, '**', 'smoothed8_*desc-preproc_bold.nii'));
    if isempty(d)
        return
    end

    names   = {d.name};
    folders = {d.folder};
    fulls   = cellfun(@(f,n) fullfile(f,n), folders, names, 'UniformOutput', false);

    idx1 = find(contains(names, 'run-01'), 1, 'first');
    if ~isempty(idx1)
        boldPath = fulls{idx1};
        return
    end

    idx2 = find(contains(names, 'run-02'), 1, 'first');
    if ~isempty(idx2)
        boldPath = fulls{idx2};
        return
    end

    boldPath = fulls{1};
end