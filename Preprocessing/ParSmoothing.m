%% Step 6: Smoothing (SLURM array-friendly + auto-subject discovery + skip-if-done + safe move)

clearvars; clc;

% Add SPM path
addpath(genpath('/scratch/lbertin/spm12'));

rawdata       = fullfile('/scratch/lbertin/Bids_test/derivatives');
smoothed_base = '/scratch/lbertin/Bids_test/smoothed';

runs_dir = {'ses-02/func'};

% -----------------------------
% Auto-discover subject folders
% -----------------------------
subs = dir(fullfile(rawdata, 'sub-*'));
subs = subs([subs.isdir]);
subjects = {subs.name};

if isempty(subjects)
    error('No sub-* folders found under: %s', rawdata);
end

% Deterministic order so array task IDs map consistently
subjects = sort(subjects);

% -----------------------------
% SLURM array: pick one subject
% -----------------------------
task_id_str = getenv('SLURM_ARRAY_TASK_ID');
if ~isempty(task_id_str)
    task_id = str2double(task_id_str);
    if isnan(task_id)
        error('SLURM_ARRAY_TASK_ID is not a valid number: %s', task_id_str);
    end

    % Array is 0-based (0-12). Convert to MATLAB 1-based index.
    idx = task_id + 1;

    if idx < 1 || idx > numel(subjects)
        error('SLURM_ARRAY_TASK_ID=%d maps to idx=%d, but number of discovered subjects is %d.', ...
              task_id, idx, numel(subjects));
    end

    subjects = subjects(idx);  % process exactly one subject
end

% -----------------------------
% Init SPM
% -----------------------------
spm('defaults', 'fMRI');
spm_jobman('initcfg');

subj_num = numel(subjects);
runs_num = numel(runs_dir);

disp('===============================');
disp('Starting smoothing...');
disp(['Raw data:      ', rawdata]);
disp(['Smoothed base: ', smoothed_base]);
disp(['# Subjects:    ', num2str(subj_num)]);
if ~isempty(task_id_str)
    disp(['SLURM_ARRAY_TASK_ID: ', task_id_str, ' (processing one subject)']);
end
disp('===============================');

for i = 1:subj_num
    subj = subjects{i};

    for sess = 1:runs_num
        disp(['Starting Smoothing for ', subj, ' ', runs_dir{sess}]);

        func_dir = fullfile(rawdata, subj, runs_dir{sess});

        % Check if the functional run folder exists
        if ~exist(func_dir, 'dir')
            disp(['Skipping missing run folder: ', func_dir]);
            continue;
        end

        % Create subject-specific output dir (do early so we can check it)
        out_dir = fullfile(smoothed_base, subj);
        if ~exist(out_dir, 'dir')
            mkdir(out_dir);
        end

        % Select functional NIfTI files (your original pattern)
        func_files = spm_select('ExtFPList', func_dir, '^sub-.*_desc-preproc_bold\.nii$', Inf);

        if isempty(func_files)
            disp(['No NIfTI files found in ', func_dir, ' - Skipping']);
            continue;
        end

        func_cells = cellstr(func_files);

        % -------------------------------------------------------
        % Skip smoothing if ALL expected outputs already exist in out_dir
        % Expected per input file: smoothed8_<basename>.nii
        % -------------------------------------------------------
        all_exist = true;
        for k = 1:numel(func_cells)
            this_in = strtrim(func_cells{k});
            [~, base, ext] = spm_fileparts(this_in);  % ext includes .nii
            expected = fullfile(out_dir, ['smoothed8_' base ext]);

            if ~exist(expected, 'file')
                all_exist = false;
                break;
            end
        end

        if all_exist
            disp(['Skipping (already smoothed): ', subj, ' ', runs_dir{sess}]);
            continue;
        end

        % -----------------------------
        % Build smoothing batch
        % -----------------------------
        matlabbatch = [];
        matlabbatch{1}.spm.spatial.smooth.data   = func_cells;
        matlabbatch{1}.spm.spatial.smooth.fwhm   = [8 8 8];
        matlabbatch{1}.spm.spatial.smooth.dtype  = 0;
        matlabbatch{1}.spm.spatial.smooth.im     = 0;
        matlabbatch{1}.spm.spatial.smooth.prefix = 'smoothed8_';

        % Save and run batch
        save(fullfile(func_dir, 'smoothing_batch.mat'), 'matlabbatch');
        spm_jobman('run', matlabbatch);
        disp(['Completed smoothing for ', subj, ' ', runs_dir{sess}]);

        % -----------------------------
        % Move smoothed files to out_dir
        % Only move files that do NOT already exist in out_dir
        % -----------------------------
        smoothed_files = spm_select('FPList', func_dir, '^smoothed8_.*\.nii$');

        if isempty(smoothed_files)
            warning('No smoothed files were produced/found in %s (unexpected).', func_dir);
            continue;
        end

        smoothed_cells = cellstr(smoothed_files);

        for f = 1:numel(smoothed_cells)
            src = strtrim(smoothed_cells{f});
            [~, b, e] = spm_fileparts(src);
            dst = fullfile(out_dir, [b e]);

            if exist(dst, 'file')
                disp(['  Output exists, not overwriting: ', dst]);
                % Optional cleanup to keep func_dir tidy:
                % delete(src);
            else
                movefile(src, out_dir);
                disp(['  Moved: ', src, ' -> ', out_dir]);
            end
        end

        % (Optional) clear to avoid any carryover
        clear matlabbatch;

    end
end

disp('===============================');
disp('Smoothing done.');