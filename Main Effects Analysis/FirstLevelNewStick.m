%-----------------------------------------------------------------------
% First-level model: Stage x Risk x Temp
% Server / SLURM version
% Subject is provided by environment variable SUBJECT_ID
%-----------------------------------------------------------------------

clear; clc;

try
    % ==========================
    % File Paths
    % ==========================
    sub = getenv('SUBJECT_ID');
    if isempty(sub)
        error('SUBJECT_ID environment variable is not set.');
    end

    dataDir   = '/scratch/lbertin/Bids_test/smoothed';
    OnsetPath = '/scratch/lbertin/Bids_test/onset_times';
    MapPath   = '/scratch/lbertin/Bids_test/Binary_Trust_subject_Info.xlsx';
    outRoot   = '/scratch/lbertin/Bids_test/smoothed/FirstLevel_Stick';

    addpath(genpath('/scratch/lbertin/spm12'));
    spm('Defaults','fMRI');
    spm_jobman('initcfg');
    spm_get_defaults('cmdline', true);

    T = readtable(MapPath);

    clear matlabbatch

    disp(['Running subject: ' sub]);

    % ==========================
    % Subject mapping
    % ==========================
    sub_num = str2double(erase(sub, 'sub-'));
    row = T.MRI_ID_Process == sub_num;

    if sum(row) ~= 1
        error('Mapping issue for %s: expected exactly 1 match in MRI_ID_Process', sub);
    end

    onset_ID = T.MRI_ID{row};
    disp(['Onset ID: ' onset_ID]);

    % define paths
    funcDir   = fullfile(dataDir, sub);
    outputDir = fullfile(outRoot, sub);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % ==========================
    % fMRI Model Specification
    % ==========================
    matlabbatch{1}.spm.stats.fmri_spec.dir = {outputDir};
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = 1;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;

    % Set condition names
    condNames = { ...
        'decision_lowRisk_lowTemp', ...
        'decision_lowRisk_highTemp', ...
        'decision_highRisk_lowTemp', ...
        'decision_highRisk_highTemp', ...
        'guess_lowRisk_lowTemp', ...
        'guess_lowRisk_highTemp', ...
        'guess_highRisk_lowTemp', ...
        'guess_highRisk_highTemp'};

    % ==========================
    % Run loop
    % ==========================
    for r = 1:2

        % Define onset file
        runOnsetFile = fullfile(OnsetPath, ['sub-' onset_ID '_task-trust_run-' num2str(r) '.csv']);

        % Split 4D file into scans
        img_pattern = sprintf('^smoothed8_.*_task-BT_run-0%d_.*desc-preproc_bold\\.nii$', r);
        scans = spm_select('ExtFPList', funcDir, img_pattern, Inf);

        if isempty(scans)
            error('Could not find run-%02d file for %s', r, sub);
        end

        matlabbatch{1}.spm.stats.fmri_spec.sess(r).scans = cellstr(scans);

        % Load onset times
        tbl = readtable(runOnsetFile);

	% calculate stick, doesn't edit csv file	
	tbl.stick = tbl.onset + tbl.duration; 

        % Check column names
        requiredVars = {'Type','Risk','Temp','onset','duration'};
        missingVars = setdiff(requiredVars, tbl.Properties.VariableNames);
        if ~isempty(missingVars)
            error('Missing required columns in %s: %s', runOnsetFile, strjoin(missingVars, ', '));
        end

        % Normalize text fields
        typeStr = lower(string(tbl.Type));
        riskStr = lower(string(tbl.Risk));
        tempStr = lower(string(tbl.Temp));

        % Remove spaces just in case
        riskStr = strrep(riskStr, ' ', '');
        tempStr = strrep(tempStr, ' ', '');

        % Pull condition values
        isDecision = strcmp(typeStr, 'decision');
        isGuess    = strcmp(typeStr, 'guess');

        isLowRisk  = strcmp(riskStr, 'low');
        isHighRisk = strcmp(riskStr, 'high');

        isLowTemp  = strcmp(tempStr, 'low');
        isHighTemp = strcmp(tempStr, 'high');

        % Check for unexpected values
        if any(~(isDecision | isGuess))
            badVals = unique(typeStr(~(isDecision | isGuess)));
            error('Unexpected Type values in %s: %s', runOnsetFile, strjoin(cellstr(badVals), ', '));
        end
        if any(~(isLowRisk | isHighRisk))
            badVals = unique(riskStr(~(isLowRisk | isHighRisk)));
            error('Unexpected Risk values in %s: %s', runOnsetFile, strjoin(cellstr(badVals), ', '));
        end
        if any(~(isLowTemp | isHighTemp))
            badVals = unique(tempStr(~(isLowTemp | isHighTemp)));
            error('Unexpected Temp values in %s: %s', runOnsetFile, strjoin(cellstr(badVals), ', '));
        end

        % Build condition indices
        condIdx = cell(1,8);
        condIdx{1} = isDecision & isLowRisk  & isLowTemp;
        condIdx{2} = isDecision & isLowRisk  & isHighTemp;
        condIdx{3} = isDecision & isHighRisk & isLowTemp;
        condIdx{4} = isDecision & isHighRisk & isHighTemp;
        condIdx{5} = isGuess    & isLowRisk  & isLowTemp;
        condIdx{6} = isGuess    & isLowRisk  & isHighTemp;
        condIdx{7} = isGuess    & isHighRisk & isLowTemp;
        condIdx{8} = isGuess    & isHighRisk & isHighTemp;

        % --------------------------
        % Conditions
        % --------------------------
        for c = 1:8
            theseOnsets = tbl.stick(condIdx{c});
            %theseDurations = tbl.duration(condIdx{c});

            if isempty(theseOnsets)
                warning('No trials found for %s, %s, run %d', sub, condNames{c}, r);
            end

            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).name = condNames{c};
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).onset = theseOnsets(:);
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).duration = 0;
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).tmod = 0;
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).pmod = struct('name', {}, 'param', {}, 'poly', {});
            matlabbatch{1}.spm.stats.fmri_spec.sess(r).cond(c).orth = 1;
        end

        % --------------------------
        % Build motion correction file
        % --------------------------
        runMotionCor = fullfile(funcDir, [sub sprintf('_ses-02_task-BT_run-0%d_desc-confounds_timeseries.tsv', r)]);

        if ~isfile(runMotionCor)
            error('Missing confound file: %s', runMotionCor);
        end

        disp(['Reading: ' runMotionCor]);
        Tconf = readtable(runMotionCor, 'FileType','text', 'Delimiter','\t');

        base_cols = {'trans_x','trans_y','trans_z','rot_x','rot_y','rot_z','framewise_displacement'};
        motion_outliers = Tconf.Properties.VariableNames(contains(Tconf.Properties.VariableNames, 'motion_outlier'));
        cols_to_extract = [base_cols, motion_outliers];

        missing = setdiff(base_cols, Tconf.Properties.VariableNames);
        if ~isempty(missing)
            error('Missing columns in confound file %s: %s', runMotionCor, strjoin(missing, ', '));
        end

        X = table2array(Tconf(:, cols_to_extract));
        X(~isfinite(X)) = 0;

        confound_txt = fullfile(outputDir, sprintf('MotCor_run-0%d.txt', r));
        writematrix(X, confound_txt, 'Delimiter', 'tab');

        % Session settings
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi = {''};
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).regress = struct('name', {}, 'val', {});
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).multi_reg = {confound_txt};
        matlabbatch{1}.spm.stats.fmri_spec.sess(r).hpf = 128;
    end

    % ==========================
    % More general settings
    % ==========================
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

    % ==========================
    % Model Estimation
    % ==========================
    matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(outputDir, 'SPM.mat')};
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 1;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    % ==========================
    % Contrast Manager
    % ==========================
    matlabbatch{3}.spm.stats.con.spmmat = {fullfile(outputDir, 'SPM.mat')};

    % Contrast order reminder:
    % 1 decision_lowRisk_lowTemp
    % 2 decision_lowRisk_highTemp
    % 3 decision_highRisk_lowTemp
    % 4 decision_highRisk_highTemp
    % 5 guess_lowRisk_lowTemp
    % 6 guess_lowRisk_highTemp
    % 7 guess_highRisk_lowTemp
    % 8 guess_highRisk_highTemp

    cons = {};
    weights = {};

    % Overall stage effects
    cons{end+1}    = 'decision > baseline';
    weights{end+1} = [1 1 1 1 0 0 0 0];

    cons{end+1}    = 'guess > baseline';
    weights{end+1} = [0 0 0 0 1 1 1 1];

    % Decision: Risk, Temp, Interaction
    cons{end+1}    = 'decision_highRisk > lowRisk';
    weights{end+1} = [-1 -1 1 1 0 0 0 0];

    cons{end+1}    = 'decision_highTemp > lowTemp';
    weights{end+1} = [-1 1 -1 1 0 0 0 0];

    cons{end+1}    = 'decision_RiskXTemp';
    weights{end+1} = [1 -1 -1 1 0 0 0 0];

    % Guess: Risk, Temp, Interaction
    cons{end+1}    = 'guess_highRisk > lowRisk';
    weights{end+1} = [0 0 0 0 -1 -1 1 1];

    cons{end+1}    = 'guess_highTemp > lowTemp';
    weights{end+1} = [0 0 0 0 -1 1 -1 1];

    cons{end+1}    = 'guess_RiskXTemp';
    weights{end+1} = [0 0 0 0 1 -1 -1 1];

    % Cross-stage factorial effects
    cons{end+1}    = 'decisionRisk > guessRisk';
    weights{end+1} = [-1 -1 1 1 1 1 -1 -1];

    cons{end+1}    = 'decisionTemp > guessTemp';
    weights{end+1} = [-1 1 -1 1 1 -1 1 -1];

    cons{end+1}    = 'decisionRiskXTemp > guessRiskXTemp';
    weights{end+1} = [1 -1 -1 1 -1 1 1 -1];

    % Write all contrasts
    for k = 1:length(cons)
        matlabbatch{3}.spm.stats.con.consess{k}.tcon.name = cons{k};
        matlabbatch{3}.spm.stats.con.consess{k}.tcon.weights = weights{k};
        matlabbatch{3}.spm.stats.con.consess{k}.tcon.sessrep = 'replsc';
    end

    matlabbatch{3}.spm.stats.con.delete = 0;

    % ==========================
    % Run the batch
    % ==========================
    spm_jobman('run', matlabbatch);

    fprintf('Finished subject %s successfully.\n', sub);
    exit(0);

catch ME
    fprintf(2, '\nERROR: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(2, '  In %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    exit(1);
end