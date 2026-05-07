%% RunOutputSignificance.m
% Usage from SLURM:
%   matlab -nodisplay -nosplash -r "RunOutputSignificance; exit"
%
% SLURM should pass the data directory as the first argument.

function RunOutputSignificance(dataDir)

    if nargin < 1 || isempty(dataDir)
        dataDir = getenv('DATA_DIR');
    end

    if isempty(dataDir)
        error('You must provide a data directory name.');
    end

    rootDir = fullfile('/scratch/lbertin/Bids_test/smoothed/SecondLevel', dataDir);

    outDir = '/scratch/lbertin/fMRI_significance';
    if ~exist(outDir,'dir'); mkdir(outDir); end

    folderName = dataDir;
    outCSV = fullfile(outDir, [folderName '.csv']);

    run_spm_secondlevel_batch_summary(rootDir, outCSV);
end
%% ================== MAIN FUNCTION ==================
function run_spm_secondlevel_batch_summary(rootDir, outCSV)

    addpath(genpath('/scratch/lbertin/spm12'));
    spm('Defaults','fMRI');
    spm_jobman('initcfg');
    spm_get_defaults('cmdline', true);

    assert(isfolder(rootDir), 'rootDir not found: %s', rootDir);

    d = dir(rootDir);
    d = d([d.isdir]);
    d = d(~ismember({d.name},{'.','..'}));

    rows = {};

    CDT_u = 0.001;
    thresDesc = 'none';
    k0 = 0;

    for ii = 1:numel(d)
        folder = fullfile(rootDir, d(ii).name);
        spmmat = fullfile(folder, 'SPM.mat');
        if ~exist(spmmat,'file')
            continue;
        end

        try
            load(spmmat, 'SPM');
            % ---- Skip if no contrasts exist in this SPM.mat ----
            if ~isfield(SPM,'xCon') || isempty(SPM.xCon)
                warning('Skipping (no SPM.xCon contrasts): %s', spmmat);
                continue;
            end
        catch ME
            warning('Could not load %s: %s', spmmat, ME.message);
            continue;
        end

        Ic_list = [1 2];
        Ic_list = Ic_list(Ic_list <= numel(SPM.xCon));
        if isempty(Ic_list)
            warning('Skipping (no contrasts 1–2 found): %s', spmmat);
            continue;
        end

        nSub = size(SPM.xY.P, 1);

        for Ic = Ic_list
            conName = SPM.xCon(Ic).name;

            [xSPM0, ok0] = get_xSPM(folder, Ic, CDT_u, k0, thresDesc);
            if ~ok0
                rows{end+1} = make_row(folder, spmmat, Ic, conName, nSub, CDT_u, k0, ...
                    NaN, NaN, 0, 0, NaN, NaN, "", NaN, ...
                    NaN, NaN, NaN, "", ...
                    NaN, NaN, NaN, "");
                continue;
            end

            [nVox0, nClus0, maxT0, maxZ0, peak0, maxK0] = summarize_xSPM(xSPM0);

            kFWEc = NaN; kFDRc = NaN;
            if isfield(xSPM0,'uc') && numel(xSPM0.uc) >= 4
                kFWEc = xSPM0.uc(3);
                kFDRc = xSPM0.uc(4);
            end

            [nVoxFWE, nClusFWE, maxKFWE, peakFWE] = deal(NaN);
            if isfinite(kFWEc) && kFWEc > 0
                [xSPMfwe, okfwe] = get_xSPM(folder, Ic, CDT_u, kFWEc, thresDesc);
                if okfwe
                    [nVoxFWE, nClusFWE, ~, ~, peakFWE, maxKFWE] = summarize_xSPM(xSPMfwe);
                else
                    nVoxFWE = 0; nClusFWE = 0; maxKFWE = NaN; peakFWE = "";
                end
            else
                nVoxFWE = 0; nClusFWE = 0; maxKFWE = NaN; peakFWE = "";
            end

            [nVoxFDR, nClusFDR, maxKFDR, peakFDR] = deal(NaN);
            if isfinite(kFDRc) && kFDRc > 0
                [xSPMfdr, okfdr] = get_xSPM(folder, Ic, CDT_u, kFDRc, thresDesc);
                if okfdr
                    [nVoxFDR, nClusFDR, ~, ~, peakFDR, maxKFDR] = summarize_xSPM(xSPMfdr);
                else
                    nVoxFDR = 0; nClusFDR = 0; maxKFDR = NaN; peakFDR = "";
                end
            else
                nVoxFDR = 0; nClusFDR = 0; maxKFDR = NaN; peakFDR = "";
            end

            rows{end+1} = make_row(folder, spmmat, Ic, conName, nSub, CDT_u, k0, ...
                kFWEc, kFDRc, nVox0, nClus0, maxT0, maxZ0, peak0, maxK0, ...
                nVoxFWE, nClusFWE, maxKFWE, peakFWE, ...
                nVoxFDR, nClusFDR, maxKFDR, peakFDR);
        end
    end

    if isempty(rows)
        warning('No SPM.mat files found under %s', rootDir);
        return;
    end

    T = struct2table([rows{:}]);
    writetable(T, outCSV);
    fprintf('Wrote summary CSV: %s\n', outCSV);
end

%% ================== HELPERS ==================
function [xSPM, ok] = get_xSPM(swd, Ic, u, k, thresDesc)
    ok = true;
    try
        x = struct();
        x.swd       = swd;
        x.Ic        = Ic;
        x.u         = u;
        x.k         = k;
        x.thresDesc = thresDesc;
        x.Im        = [];
        x.title     = '';
        [~, xSPM] = spm_getSPM(x);
    catch ME
        warning('spm_getSPM failed for %s (Ic=%d): %s', swd, Ic, ME.message);
        xSPM = struct();
        ok = false;
    end
end

function [nVox, nClus, maxT, maxZ, peakXYZ, maxK] = summarize_xSPM(xSPM)
    if ~isfield(xSPM,'Z') || isempty(xSPM.Z)
        nVox = 0; nClus = 0; maxT = NaN; maxZ = NaN; peakXYZ = ""; maxK = NaN;
        return;
    end

    nVox = numel(xSPM.Z);

    try
        A = spm_clusters(xSPM.XYZ);
        clusIDs = unique(A);
        nClus = numel(clusIDs);
        counts = accumarray(A(:), 1);
        maxK = max(counts);
    catch
        nClus = NaN;
        maxK = NaN;
    end

    [maxZ, idx] = max(xSPM.Z);
    if isfield(xSPM,'T') && ~isempty(xSPM.T)
        maxT = xSPM.T(idx);
    else
        maxT = NaN;
    end

    xyz = xSPM.XYZ(:, idx);
    peakXYZ = sprintf('%d,%d,%d', xyz(1), xyz(2), xyz(3));
end

function R = make_row(folder, spmmat, Ic, conName, nSub, cdt_u, k_input, ...
    kFWEc, kFDRc, nVox0, nClus0, maxT0, maxZ0, peak0, maxK0, ...
    nVoxFWE, nClusFWE, maxKFWE, peakFWE, ...
    nVoxFDR, nClusFDR, maxKFDR, peakFDR)

    [~, folderName] = fileparts(folder);

    R = struct();
    R.folder_name          = string(folderName);
    R.spm_mat              = string(spmmat);
    R.contrast_index       = Ic;
    R.contrast_name        = string(conName);
    R.n_subjects           = nSub;

    R.cdt_p_unc            = cdt_u;
    R.k_input              = k_input;

    R.kcrit_FWEc           = kFWEc;
    R.kcrit_FDRc           = kFDRc;

    R.n_voxels_CDT_k0      = nVox0;
    R.n_clusters_CDT_k0    = nClus0;
    R.maxT_CDT_k0          = maxT0;
    R.maxZ_CDT_k0          = maxZ0;
    R.peak_xyz_CDT_k0      = string(peak0);
    R.largest_cluster_k0   = maxK0;

    R.n_voxels_FWEc        = nVoxFWE;
    R.n_clusters_FWEc      = nClusFWE;
    R.largest_cluster_FWEc = maxKFWE;
    R.peak_xyz_FWEc        = string(peakFWE);

    R.n_voxels_FDRc        = nVoxFDR;
    R.n_clusters_FDRc      = nClusFDR;
    R.largest_cluster_FDRc = maxKFDR;
    R.peak_xyz_FDRc        = string(peakFDR);
end