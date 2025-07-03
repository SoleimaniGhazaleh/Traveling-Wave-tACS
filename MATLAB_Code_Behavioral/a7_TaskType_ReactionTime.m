%% STEP 1: Filter valid trials
validTrials = allTrials(~isnan(allTrials.Correct) & allTrials.Correct ~= -1, :);

% Convert to categorical
validTrials.Condition = categorical(validTrials.Condition);
validTrials.TaskType = categorical(validTrials.TaskType);

% Define condition/task labels
condOrder = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
taskOrder = ["2", "3"];  % assuming TaskType is numeric-coded (2 or 3)

% STEP 2: Subject-level mean Reaction Time per Condition × TaskType
summaryRT = varfun(@mean, validTrials, ...
    'InputVariables', 'Latency', ...
    'GroupingVariables', {'SubjectID', 'Condition', 'TaskType'});

summaryRT.Condition = categorical(string(summaryRT.Condition), condOrder, 'Ordinal', true);
summaryRT.TaskType = categorical(string(summaryRT.TaskType), taskOrder, 'Ordinal', true);
summaryRT = sortrows(summaryRT, {'Condition', 'TaskType'});

% Combine for x-axis grouping
summaryRT.CondTask = strcat(string(summaryRT.Condition), " / ", string(summaryRT.TaskType));
groupLabels = categories(categorical(summaryRT.CondTask));  % all 12 combinations

%% STEP 3: Plot grouped box + scatter by Condition × TaskType
figure; hold on;

% Define bar positions
xPositions = 1:length(groupLabels);

% Colors: red for 2-back, blue for 3-back
%taskColors = containers.Map({'2', '3'}, {[1 0.6 0.6], [0.4 0.8 1]});  % light red & light blue

taskColors = containers.Map( ...
    {'2', '3'}, ...
    {[0.973, 0.463, 0.427], [0.0, 0.749, 0.769]});  % red (2-back) & blue (3-back)


for i = 1:length(groupLabels)
    label = groupLabels{i};
    parts = split(label, " / ");
    cond = parts{1};
    task = parts{2};

    % Find data for this group
    idx = summaryRT.CondTask == label;
    y = summaryRT.mean_Latency(idx);

    % Jittered scatter
    x_jitter = 0.15 * randn(sum(idx), 1) + xPositions(i);

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);

    % Boxplot
    boxchart(repmat(xPositions(i), sum(idx), 1), y, ...
        'BoxFaceColor', taskColors(task), ...
        'BoxFaceAlpha', 0.5, ...
        'LineWidth', 1.3, ...
        'MarkerStyle', 'none');
end

% Final plot formatting
set(gca, 'XTick', xPositions, 'XTickLabel', groupLabels, 'FontSize', 12);
xtickangle(45);
ylabel('Mean Reaction Time (s)');
title('Reaction Time by Condition & TaskType (Box + Scatter)');
ylim([0.3 1]);
grid on;

%% Anova
%% STEP 4: Linear Mixed-Effects Model (Condition × TaskType)
% Make sure all necessary columns are properly typed
summaryRT.SubjectID = categorical(summaryRT.SubjectID);
summaryRT.Condition = categorical(summaryRT.Condition, condOrder, 'Ordinal', true);
summaryRT.TaskType = categorical(summaryRT.TaskType, taskOrder, 'Ordinal', true);

% Fit LME model: Reaction Time ~ Condition * TaskType + (1|SubjectID)
lme_rt = fitlme(summaryRT, 'mean_Latency ~ Condition * TaskType + (1|SubjectID)');

% Display ANOVA table
anovaResults_rt = anova(lme_rt);

disp('------------------------------');
disp('Repeated-Measures LME ANOVA (Condition × TaskType):');
disp(anovaResults_rt);

%% Interaction
%% STEP 5: LME - Parse CondTask into Frequency, Phase, TaskType

% Only use active conditions (exclude Sham)
activeRT = summaryRT(~contains(string(summaryRT.CondTask), 'Sham'), :);

% Parse CondTask → Frequency, Phase, TaskType
n = height(activeRT);
Frequency = strings(n,1);
Phase = strings(n,1);
TaskType = strings(n,1);

for i = 1:n
    token = split(activeRT.CondTask(i), " / ");
    freqPhase = token{1};
    TaskType(i) = token{2};

    if startsWith(freqPhase, "4Hz")
        Frequency(i) = "4Hz";
    else
        Frequency(i) = "7Hz";
    end

    if contains(freqPhase, "45")
        Phase(i) = "45";
    else
        Phase(i) = "315";
    end
end

% Add to table as categorical
activeRT.Frequency = categorical(Frequency);
activeRT.Phase = categorical(Phase);
activeRT.TaskType = categorical(TaskType);
activeRT.SubjectID = categorical(activeRT.SubjectID);

% Fit LME model with all main effects + interactions
lme_freq_phase = fitlme(activeRT, ...
    'mean_Latency ~ Frequency * Phase * TaskType + (1|SubjectID)');

% Display ANOVA table
anovaResults_fp = anova(lme_freq_phase);

disp('------------------------------');
disp('LME ANOVA for Frequency × Phase × TaskType:');
disp(anovaResults_fp);


%% Two by Two t-test

%% STEP 6: Two-by-Two Paired t-tests Across All Conditions (CondTask)

conds = categories(categorical(summaryRT.CondTask));
nConds = length(conds);

% Initialize result table
ttestResults = table();
row = 1;

for i = 1:nConds-1
    for j = i+1:nConds
        cond1 = conds{i};
        cond2 = conds{j};

        % Extract subject-level data for both conditions
        data1 = summaryRT.mean_Latency(summaryRT.CondTask == cond1);
        data2 = summaryRT.mean_Latency(summaryRT.CondTask == cond2);
        subs1 = summaryRT.SubjectID(summaryRT.CondTask == cond1);
        subs2 = summaryRT.SubjectID(summaryRT.CondTask == cond2);

        % Match subjects present in both conditions
        [commonSubs, i1, i2] = intersect(subs1, subs2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        % Skip if fewer than 3 subjects overlap (not reliable)
        if length(commonSubs) < 3
            continue;
        end

        % Paired t-test
        [~, p, ~, stats] = ttest(paired1, paired2);

        % Save result
        ttestResults(row,:) = table(...
            string(cond1), string(cond2), ...
            p, stats.tstat, stats.df, length(commonSubs), ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df', 'nSubjects'});

        row = row + 1;
    end
end

% Display
disp('------------------------------');
disp('Pairwise Paired t-Tests for All CondTask Combinations:');
disp(ttestResults);

% Optional: Save to CSV
% writetable(ttestResults, 'pairwise_ttests_all_conditions.csv');


%% ========== New figure
%% NEW SECTION: Reaction Time by Condition × TaskType (Sham2 Removed)

%% NEW SECTION: RT by Condition × TaskType (Sham2 Removed, Custom Order)

% STEP 1: Filter only desired conditions
customConds = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryRT_filtered = summaryRT(ismember(string(summaryRT.Condition), customConds), :);

% STEP 2: Sort conditions and tasks
summaryRT_filtered.Condition = categorical(string(summaryRT_filtered.Condition), customConds, 'Ordinal', true);
summaryRT_filtered = sortrows(summaryRT_filtered, {'Condition', 'TaskType'});

% STEP 3: Create combined CondTask label
summaryRT_filtered.CondTask = strcat(string(summaryRT_filtered.Condition), " / ", string(summaryRT_filtered.TaskType));

% STEP 4: Define ordered labels
groupLabels = strcat( ...
    repmat(customConds, 1, 2), ...                % Repeat conditions
    " / ", ...
    repelem(["2", "3"], numel(customConds)) ...   % Repeat tasks
);

xPositions = 1:length(groupLabels);

% STEP 5: Plot
figure; hold on;
%taskColors = containers.Map({'2', '3'}, {[1 0.6 0.6], [0.4 0.8 1]});  % light red & blue
taskColors = containers.Map( ...
    {'2', '3'}, ...
    {[0.973, 0.463, 0.427], [0.0, 0.749, 0.769]});  % red (2-back) & blue (3-back)


for i = 1:length(groupLabels)
    label = groupLabels(i);
    parts = split(label, " / ");
    cond = parts{1};
    task = parts{2};

    idx = summaryRT_filtered.CondTask == label;
    y = summaryRT_filtered.mean_Latency(idx);
    x_jitter = 0.15 * randn(sum(idx), 1) + xPositions(i);

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
    boxchart(repmat(xPositions(i), sum(idx), 1), y, ...
        'BoxFaceColor', taskColors(task), ...
        'BoxFaceAlpha', 0.5, ...
        'LineWidth', 1.3, ...
        'MarkerStyle', 'none');
end

% STEP 6: Formatting
set(gca, 'XTick', xPositions, 'XTickLabel', groupLabels, 'FontSize', 12);
xtickangle(45);
ylabel('Mean Reaction Time (s)');
%title('Reaction Time by Condition × TaskType (Sham2 Removed)');
ylim([0.3 1]);
grid on;
%% 
%% NEW SECTION: Summary Table for Reporting Reaction Time (Condition × TaskType)

% Use filtered dataset (Sham2 removed)
customConds = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryRT_filtered = summaryRT(ismember(string(summaryRT.Condition), customConds), :);

% Preallocate result table
reportTableRT = table();
row = 1;

for cond = customConds
    for task = ["2", "3"]
        % Filter rows
        idx = (summaryRT_filtered.Condition == cond) & (summaryRT_filtered.TaskType == task);
        rtValues = summaryRT_filtered.mean_Latency(idx);

        if isempty(rtValues)
            continue;
        end

        % Compute stats
        N = numel(rtValues);
        meanRT = mean(rtValues);
        sdRT = std(rtValues);
        semRT = sdRT / sqrt(N);

        % Save to table
        reportTableRT(row,:) = table( ...
            string(cond), string(task), N, meanRT, sdRT, semRT, ...
            'VariableNames', {'Condition', 'TaskType', 'N', 'MeanRT', 'SD', 'SEM'} ...
        );
        row = row + 1;
    end
end

% Display table
disp('------------------------------');
disp('Reaction Time Summary Table (for Reporting):');
disp(reportTableRT);

% Optional: Save to CSV
% writetable(reportTableRT, 'reaction_time_summary_table.csv');
