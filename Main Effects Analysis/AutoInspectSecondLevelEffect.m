%% SummarizeFirstLevelContrasts_MaskVsWholeBrain.m
% Iterates through 1st-level subject folders and summarizes each con_*.nii
% both whole-brain and within an explicit group mask.
%
% Output: CSV with one row per subject x contrast.
%
% Lindsey / Hopper / SPM12

clearvars; clc;

% -----------------------------
% Inputs
% -----------------------------
rootDir   = '/scratch/lbertin/Bids_test/smoothed/FirstLevel_runs12/FirstLevel_2runs_RTDur_ONLYDecision_RiskTempPmods_CONSINC';
groupMask = '/scratch/lbertin/group_mask.nii';
outCSV    = fullfile(rootDir, 'FirstLevel_contrast_summary_mask_vs_wholebrain.csv');

% -----------------------------
% SPM setup
% -----------------------------
addpath(genpath('/scratch/lbertin/spm12'));
spm('Defaults','fMRI');
spm_jobman('initcfg');
spm_get_defaults('cmdline', true);

assert(isfolder(rootDir), 'rootDir not found: %s', rootDir);
assert(exist(groupMask,'file')==2, 'group mask not found: %s', groupMask);

% -----------------------------
% Discover subjects
% -----------------------------
subs = dir(fullfile(rootDir, 'sub-*'));
subs = subs([subs.isdir]);

if isempty(subs)
    error('No sub-* folders found under: %s', rootDir);
end

% -----------------------------
% Discover contrast indices from first subject (or all subjects)
% -----------------------------
% We’ll discover all con_*.nii filenames that appear in ANY subject folder,
% then make a unified sorted list of indices.
allConIdx = [];

for s = 1:numel(subs)
    conFiles = dir(fullfile(rootDir, subs(s).name, 'con_*.nii'));
    for k = 1:numel(conFiles)
        tok = regexp(conFiles(k).name, '^con_(\d+)\.nii$', 'tokens', 'once');
        if ~isempty(tok)
            allConIdx(end+1) = str2double(tok{1}); %#ok<AGROW>
        end
    end
end

allConIdx = unique(allConIdx);
allConIdx = allConIdx(~isnan(allConIdx));
allConIdx = sort(allConIdx);

if isempty(allConIdx)
    error('No con_*.nii files found under subject folders in: %s', rootDir);
end

fprintf('Found %d subject folders.\n', numel(subs));
fprintf('Found %d unique contrasts: %s\n', numel(allConIdx), strjoin(arrayfun(@(x)sprintf('%04d',x),allConIdx,'UniformOutput',false), ', '));

% -----------------------------
% Load mask once
% -----------------------------
Vmask = spm_vol(groupMask);
Ymask = spm_read_vols(Vmask);

mask_ok = isfinite(Ymask) & (Ymask > 0);
mask_n  = nnz(mask_ok);

if mask_n == 0
    error('Group mask has zero in-mask voxels (mask_n=0). Check: %s', groupMask);
end

% Precompute mask voxel indices (in voxel space of mask)
[mask_x, mask_y, mask_z] = ind2sub(size(Ymask), find(mask_ok));
mask_vox = [mask_x mask_y mask_z];

% -----------------------------
% Helper for safe stats
% -----------------------------
safe_stats = @(vec) local_safe_stats(vec);

% -----------------------------
% Iterate subject x contrast
% -----------------------------
rows = {};
row_i = 0;

for s = 1:numel(subs)
    subName = subs(s).name;
    subDir  = fullfile(rootDir, subName);

    for ci = 1:numel(allConIdx)
        conIdx = allConIdx(ci);
        conName = sprintf('con_%04d.nii', conIdx);
        conPath = fullfile(subDir, conName);

        row_i = row_i + 1;
        R = local_make_row(subName, conIdx, conPath);

        if exist(conPath,'file') ~= 2
            R.status  = "MISSING_CON";
            R.message = "con file not found";
            rows{row_i} = R; %#ok<SAGROW>
            continue;
        end

        % Load contrast volume
        try
            V = spm_vol(conPath);
            Y = spm_read_vols(V);
        catch ME
            R.status  = "READ_FAIL";
            R.message = string(ME.message);
            rows{row_i} = R; %#ok<SAGROW>
            continue;
        end

        % Whole-brain definition: finite voxels, exclude exact zeros
        whole_ok = isfinite(Y) & (Y ~= 0);
        whole_n  = nnz(whole_ok);

        if whole_n == 0
            R.status  = "NO_NONZERO_VOXELS";
            R.message = "All voxels were 0 or non-finite";
            rows{row_i} = R; %#ok<SAGROW>
            continue;
        end

        Ywhole = Y(whole_ok);

        % Masked extraction:
        % If con image grid differs from mask grid, record it clearly.
        if any(V.dim ~= Vmask.dim) || max(abs(V.mat(:) - Vmask.mat(:))) > 1e-6
            R.mask_status  = "MASK_MISMATCH_GRID";
            R.mask_message = "con image grid does not match group mask (dim/mat mismatch)";
            % We can still compute whole-brain stats; mask stats left NaN.
        else
            R.mask_status  = "OK";
            R.mask_message = "";
            YmaskVals = Y(mask_ok);
            % For mask stats, also exclude zeros (to mirror whole-brain)
            masked_ok = isfinite(YmaskVals) & (YmaskVals ~= 0);
            Ymasked = YmaskVals(masked_ok);
            R.mask_n_inmask_total = mask_n;
            R.mask_n_used_nonzero = numel(Ymasked);

            if isempty(Ymasked)
                R.mask_status  = "NO_MASKED_NONZERO";
                R.mask_message = "No finite nonzero voxels within mask";
            else
                S_mask = safe_stats(Ymasked);
                R.mask_min = S_mask.minv;
                R.mask_max = S_mask.maxv;
                R.mask_mean = S_mask.meanv;
                R.mask_std  = S_mask.stdv;
                R.mask_median = S_mask.medv;
                R.mask_mad    = S_mask.madv;
                R.mask_pct_pos = S_mask.pct_pos;
                R.mask_nnzw = S_mask.nnz;
            end
        end

        % Whole-brain stats
        S_whole = safe_stats(Ywhole);
        R.status  = "OK";
        R.message = "";

        R.whole_min = S_whole.minv;
        R.whole_max = S_whole.maxv;
        R.whole_mean = S_whole.meanv;
        R.whole_std  = S_whole.stdv;
        R.whole_median = S_whole.medv;
        R.whole_mad    = S_whole.madv;
        R.whole_pct_pos = S_whole.pct_pos;
        R.whole_nnzw = S_whole.nnz;

        rows{row_i} = R; %#ok<SAGROW>
    end
end

% -----------------------------
% Write CSV
% -----------------------------
T = struct2table([rows{:}]);
writetable(T, outCSV);
fprintf('\nWrote CSV:\n%s\n', outCSV);

%% ======================= Local functions ============================
function R = local_make_row(subName, conIdx, conPath)
R = struct();
R.subject = string(subName);
R.contrast_index = conIdx;
R.contrast_file  = string(conPath);

R.status  = "";
R.message = "";

% Whole-brain outputs
R.whole_nnzw = NaN;
R.whole_min = NaN;
R.whole_max = NaN;
R.whole_mean = NaN;
R.whole_std  = NaN;
R.whole_median = NaN;
R.whole_mad    = NaN;
R.whole_pct_pos = NaN;

% Mask outputs
R.mask_status = "";
R.mask_message = "";
R.mask_n_inmask_total = NaN;
R.mask_n_used_nonzero = NaN;
R.mask_nnzw = NaN;
R.mask_min = NaN;
R.mask_max = NaN;
R.mask_mean = NaN;
R.mask_std  = NaN;
R.mask_median = NaN;
R.mask_mad    = NaN;
R.mask_pct_pos = NaN;
end

function S = local_safe_stats(vec)
vec = vec(:);
vec = vec(isfinite(vec));

S.nnz = numel(vec);
if isempty(vec)
    S.minv = NaN; S.maxv = NaN; S.meanv = NaN; S.stdv = NaN;
    S.medv = NaN; S.madv = NaN; S.pct_pos = NaN;
    return;
end

S.minv = min(vec);
S.maxv = max(vec);
S.meanv = mean(vec);
S.stdv  = std(vec, 0);

S.medv = median(vec);
S.madv = mad(vec, 1);

S.pct_pos = mean(vec > 0) * 100;
end