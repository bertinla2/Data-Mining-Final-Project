%-----------------------------------------------------------------------
% Second-level model
% Server / SLURM version
% Contrast is provided by environment variable CONTRAST_ID
%-----------------------------------------------------------------------

clear; clc;

try
    % ==========================
    % File Paths
    % ==========================
    c_str = getenv('CONTRAST_ID');
    if isempty(c_str)
        error('CONTRAST_ID environment variable is not set.');
    end

    c = str2double(c_str);
    if isnan(c) || c < 1
        error('Invalid CONTRAST_ID: %s', c_str);
    end

    % Full list
    subjects = {'sub-331', 'sub-332', 'sub-336', 'sub-338', 'sub-339', 'sub-340', 'sub-341', 'sub-342', 'sub-343', 'sub-344', 'sub-345', 'sub-346', 'sub-347', 'sub-348', 'sub-349', 'sub-350', 'sub-351', 'sub-352', 'sub-353', 'sub-354', 'sub-356', 'sub-357', 'sub-359', 'sub-360', 'sub-361', 'sub-363', 'sub-364', 'sub-365', 'sub-368', 'sub-369', 'sub-370', 'sub-399', 'sub-400', 'sub-402', 'sub-404', 'sub-405', 'sub-406', 'sub-407', 'sub-408', 'sub-409', 'sub-410', 'sub-411', 'sub-412', 'sub-413', 'sub-414', 'sub-416', 'sub-417', 'sub-419', 'sub-420', 'sub-421', 'sub-422', 'sub-423', 'sub-424', 'sub-425', 'sub-426', 'sub-428', 'sub-429', 'sub-430', 'sub-431', 'sub-432', 'sub-433', 'sub-471', 'sub-473', 'sub-476', 'sub-477', 'sub-478', 'sub-479', 'sub-480', 'sub-482', 'sub-484', 'sub-485', 'sub-486', 'sub-487', 'sub-488', 'sub-489', 'sub-491', 'sub-493', 'sub-519', 'sub-526', 'sub-527', 'sub-529'};

    dataDir = '/scratch/lbertin/Bids_test/smoothed/FirstLevel_Stick';
    outRoot = '/scratch/lbertin/Bids_test/smoothed/SecondLevel_Stick';
    mapPath = '/scratch/lbertin/Bids_test/Binary_Trust_subject_Info.xlsx';
    groupMask= '/scratch/lbertin/group_mask.nii';

    if ~exist(outRoot, 'dir')
        mkdir(outRoot);
    end

    addpath(genpath('/scratch/lbertin/spm12'));
    spm('Defaults','fMRI');
    spm_jobman('initcfg');
    spm_get_defaults('cmdline', true);

    T = readtable(mapPath);

    % ==========================
    % Main
    % ==========================
    nContrasts = 11;

    if c > nContrasts
        error('CONTRAST_ID %d is out of range. nContrasts = %d', c, nContrasts);
    end

    fprintf('\nProcessing contrast %d\n', c);

    conFilesAll  = {};
    conFilesGain = {};
    conFilesLoss = {};

    % Pull contrast files
    for s = 1:length(subjects)
        sub = subjects{s};
        subNum = str2double(erase(sub, 'sub-'));

        row = T.MRI_ID_Process == subNum;
        if sum(row) ~= 1
            error('Mapping issue for %s: expected exactly 1 match in MRI_ID_Process', sub);
        end

        if ~ismember('Frame', T.Properties.VariableNames)
            error('Column "Frame" not found in subject info file.');
        end

        frameVal = string(T.Frame{row});
        frameVal = strtrim(lower(frameVal));

        subDir = fullfile(dataDir, sub);
        conName = sprintf('con_%04d.nii', c);
        conPath = fullfile(subDir, conName);

        if ~isfile(conPath)
            error('Missing contrast file: %s', conPath);
        end

        conEntry = [conPath ',1'];
        conFilesAll{end+1,1} = conEntry;

        if strcmp(frameVal, 'gain')
            conFilesGain{end+1,1} = conEntry;
        elseif strcmp(frameVal, 'loss')
            conFilesLoss{end+1,1} = conEntry;
        else
            error('Unexpected Frame value for %s: %s', sub, frameVal);
        end
    end

    fprintf('Total included subjects: %d\n', numel(conFilesAll));
    fprintf('Gain subjects: %d\n', numel(conFilesGain));
    fprintf('Loss subjects: %d\n', numel(conFilesLoss));

    if isempty(conFilesGain) || isempty(conFilesLoss)
        error('One of the frame groups is empty for contrast %d.', c);
    end

    % ==========================
    % Factorial Design Spec - One Sample T Test
    % ==========================
    clear matlabbatch

    outDir_T1 = fullfile(outRoot, sprintf('con_%04d_T1_all', c));
    if exist(outDir_T1, 'dir')
        rmdir(outDir_T1, 's');
    end
    mkdir(outDir_T1);

    matlabbatch{1}.spm.stats.factorial_design.dir = {outDir_T1};
    matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = conFilesAll;
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {groupMask};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    % ==========================
    % Model Estimation
    % ==========================
    matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(outDir_T1, 'SPM.mat')};
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    % ==========================
    % Contrast Manager
    % ==========================
    matlabbatch{3}.spm.stats.con.spmmat = {fullfile(outDir_T1, 'SPM.mat')};

    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'group mean positive';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = 1;
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';

    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'group mean negative';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = -1;
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';

    matlabbatch{3}.spm.stats.con.delete = 0;

    spm_jobman('run', matlabbatch);

    % ==========================
    % Factorial Design Spec - Two Sample T Test
    % ==========================
    clear matlabbatch

    outDir_T2 = fullfile(outRoot, sprintf('con_%04d_T2_frame', c));
    if exist(outDir_T2, 'dir')
        rmdir(outDir_T2, 's');
    end
    mkdir(outDir_T2);

    matlabbatch{1}.spm.stats.factorial_design.dir = {outDir_T2};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = conFilesGain;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = conFilesLoss;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0;

    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {groupMask};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    % ==========================
    % Model Estimation
    % ==========================
    matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(outDir_T2, 'SPM.mat')};
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    % ==========================
    % Contrast Manager
    % ==========================
    matlabbatch{3}.spm.stats.con.spmmat = {fullfile(outDir_T2, 'SPM.mat')};

    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Gain > Loss';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';

    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Loss > Gain';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';

    matlabbatch{3}.spm.stats.con.delete = 0;

    spm_jobman('run', matlabbatch);

    fprintf('Finished contrast %d successfully.\n', c);
    exit(0);

catch ME
    fprintf(2, '\nERROR: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  In %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    exit(1);
end