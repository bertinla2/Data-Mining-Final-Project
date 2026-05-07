% ==========================
% USER INPUTS
% ==========================
firstLevelRoot = '/scratch/lbertin/Bids_test/smoothed/FirstLevel_Stick';

subjects = { ...
'sub-331','sub-332','sub-336','sub-338','sub-339','sub-340','sub-341','sub-342','sub-343','sub-344', ...
'sub-345','sub-346','sub-347','sub-348','sub-349','sub-350','sub-351','sub-352','sub-353','sub-354', ...
'sub-356','sub-357','sub-359','sub-360','sub-361','sub-363','sub-364','sub-365','sub-368','sub-369', ...
'sub-370','sub-399','sub-400','sub-402','sub-404','sub-405','sub-406','sub-407','sub-408','sub-409', ...
'sub-410','sub-411','sub-412','sub-413','sub-414','sub-416','sub-417','sub-419','sub-420','sub-421', ...
'sub-422','sub-423','sub-424','sub-425','sub-426','sub-428','sub-429','sub-430','sub-431','sub-432', ...
'sub-433','sub-471','sub-473','sub-476','sub-477','sub-478','sub-479','sub-480','sub-482','sub-484', ...
'sub-485','sub-486','sub-487','sub-488','sub-489','sub-491','sub-493','sub-519','sub-526','sub-527', ...
'sub-529' ...
};

coords = [
    -10 42  -8;
    -56 -70 34;
    16 -18 44;
     16  48  2;
    46 -42 2;
    -42 -50 8;
    -12 -12 56;
     22 -84 38
];

coord_labels = {'Con4C1','Con8C1','Con10C1','Con10C2','Con10C3','Con10C4','Con10C5','Con10C6'};

% All conditions to extract
conditions = {
    'decision_lowRisk_lowTemp'
    'decision_lowRisk_highTemp'
    'decision_highRisk_lowTemp'
    'decision_highRisk_highTemp'
    'guess_lowRisk_lowTemp'
    'guess_lowRisk_highTemp'
    'guess_highRisk_lowTemp'
    'guess_highRisk_highTemp'
};

% ==========================
% EXTRACTION
% ==========================
rows = {};

for i = 1:numel(subjects)
    sub = subjects{i};
    subDir = fullfile(firstLevelRoot, sub);

    load(fullfile(subDir,'SPM.mat'),'SPM');
    names = SPM.xX.name;

    for c = 1:size(coords,1)
        coord = coords(c,:);

        for cond = 1:numel(conditions)
            pattern = conditions{cond};

            % Find all matching regressors (across runs)
            idx = find(contains(names, pattern));

            if isempty(idx)
                warning('%s missing in %s', pattern, sub);
                beta_val = NaN;
            else
                vals = nan(numel(idx),1);

                
             for k = 1:numel(idx)
                betaFile = fullfile(subDir, sprintf('beta_%04d.nii', idx(k)));

                if ~isfile(betaFile)
                    warning('Missing beta file: %s', betaFile);
                    continue;
                end

                V = spm_vol(betaFile);
                
                % Convert MNI mm to voxel coordinates
                vox = V.mat \ [coord 1]';
                
                % Check bounds
                in_bounds = ...
                    vox(1) >= 1 && vox(1) <= V.dim(1) && ...
                    vox(2) >= 1 && vox(2) <= V.dim(2) && ...
                    vox(3) >= 1 && vox(3) <= V.dim(3);
                
                if ~in_bounds
                    vals(k) = NaN;
                else
                    vals(k) = spm_sample_vol(V, vox(1), vox(2), vox(3), 1);
                end
             end
                % average across runs
                beta_val = mean(vals,'omitnan');
            end

            rows(end+1,:) = {
                sub, coord_labels{c}, coord(1), coord(2), coord(3), ...
                pattern, beta_val
            };
        end
    end
end

T = cell2table(rows, 'VariableNames', ...
    {'Subject','Coord','X','Y','Z','Condition','Beta'});

writetable(T, fullfile(firstLevelRoot,'all_condition_betas.csv'));

disp(T)