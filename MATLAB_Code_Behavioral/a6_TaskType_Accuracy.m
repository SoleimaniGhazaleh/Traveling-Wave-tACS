%% ACCURACY ANALYSIS

%% STEP 1: Filter valid trials
validTrials = allTrials(~isnan(allTrials.Correct) & allTrials.Correct ~= -1, :);

% Convert to categorical
validTrials.Condition = categorical(validTrials.Condition);
validTrials.TaskType = categorical(validTrials.TaskType);

% Define condition/task labels
condOrder = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
taskOrder = ["2", "3"];  % 2-back and 3-back

%% STEP 2: Subject-level Accuracy per Condition × TaskType
summaryAcc = varfun(@mean, validTrials, ...
    'InputVariables', 'Correct', ...
    'GroupingVariables', {'SubjectID', 'Condition', 'TaskType'});

summaryAcc.Condition = categorical(string(summaryAcc.Condition), condOrder, 'Ordinal', true);
summaryAcc.TaskType = categorical(string(summaryAcc.TaskType), taskOrder, 'Ordinal', true);
summaryAcc = sortrows(summaryAcc, {'Condition', 'TaskType'});

% Combine for grouped plotting
summaryAcc.CondTask = strcat(string(summaryAcc.Condition), " / ", string(summaryAcc.TaskType));
groupLabels = categories(categorical(summaryAcc.CondTask));

%% STEP 3: Plot grouped box + scatter by Condition × TaskType
figure; hold on;
xPositions = 1:length(groupLabels);

% Color mapping
%taskColors = containers.Map({'2', '3'}, {[1 0.6 0.6], [0.4 0.8 1]});  % light red & blue
taskColors = containers.Map( ...
    {'2', '3'}, ...
    {[0.973, 0.463, 0.427], [0.0, 0.749, 0.769]});  % red (2-back) & blue (3-back)


for i = 1:length(groupLabels)
    label = groupLabels{i};
    parts = split(label, " / ");
    cond = parts{1};
    task = parts{2};

    idx = summaryAcc.CondTask == label;
    y = summaryAcc.mean_Correct(idx);
    x_jitter = 0.15 * randn(sum(idx), 1) + xPositions(i);

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
    boxchart(repmat(xPositions(i), sum(idx), 1), y, ...
        'BoxFaceColor', taskColors(task), ...
        'BoxFaceAlpha', 0.5, ...
        'LineWidth', 1.3, ...
        'MarkerStyle', 'none');
end

set(gca, 'XTick', xPositions, 'XTickLabel', groupLabels, 'FontSize', 12);
xtickangle(45);
ylabel('Accuracy (Proportion Correct)');
title('Accuracy by Condition & TaskType (Box + Scatter)');
ylim([0.5 1.05]);
grid on;

%% STEP 4: LME - Condition × TaskType for Accuracy
summaryAcc.SubjectID = categorical(summaryAcc.SubjectID);
summaryAcc.Condition = categorical(summaryAcc.Condition, condOrder, 'Ordinal', true);
summaryAcc.TaskType = categorical(summaryAcc.TaskType, taskOrder, 'Ordinal', true);

lme_acc = fitlme(summaryAcc, 'mean_Correct ~ Condition * TaskType + (1|SubjectID)');
anovaResults_acc = anova(lme_acc);
disp('------------------------------');
disp('Repeated-Measures LME ANOVA for Accuracy (Condition × TaskType):');
disp(anovaResults_acc);

%% STEP 5: LME - Frequency × Phase × TaskType for Accuracy
activeAcc = summaryAcc(~contains(string(summaryAcc.CondTask), 'Sham'), :);

% Parse CondTask into Frequency, Phase, TaskType
n = height(activeAcc);
Frequency = strings(n,1);
Phase = strings(n,1);
TaskType = strings(n,1);

for i = 1:n
    token = split(activeAcc.CondTask(i), " / ");
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

activeAcc.Frequency = categorical(Frequency);
activeAcc.Phase = categorical(Phase);
activeAcc.TaskType = categorical(TaskType);
activeAcc.SubjectID = categorical(activeAcc.SubjectID);

lme_fp_acc = fitlme(activeAcc, ...
    'mean_Correct ~ Frequency * Phase * TaskType + (1|SubjectID)');
anovaResults_fp_acc = anova(lme_fp_acc);

disp('------------------------------');
disp('LME ANOVA for Accuracy: Frequency × Phase × TaskType:');
disp(anovaResults_fp_acc);

%% STEP 6: Two-by-Two Paired t-tests for Accuracy

conds = categories(categorical(summaryAcc.CondTask));
nConds = length(conds);

ttestResultsAcc = table();
row = 1;

for i = 1:nConds-1
    for j = i+1:nConds
        cond1 = conds{i};
        cond2 = conds{j};

        data1 = summaryAcc.mean_Correct(summaryAcc.CondTask == cond1);
        data2 = summaryAcc.mean_Correct(summaryAcc.CondTask == cond2);
        subs1 = summaryAcc.SubjectID(summaryAcc.CondTask == cond1);
        subs2 = summaryAcc.SubjectID(summaryAcc.CondTask == cond2);

        [commonSubs, i1, i2] = intersect(subs1, subs2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        if length(commonSubs) < 3
            continue;
        end

        [~, p, ~, stats] = ttest(paired1, paired2);

        ttestResultsAcc(row,:) = table(...
            string(cond1), string(cond2), ...
            p, stats.tstat, stats.df, length(commonSubs), ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df', 'nSubjects'});

        row = row + 1;
    end
end

disp('------------------------------');
disp('Pairwise Paired t-Tests for Accuracy (All CondTask Combinations):');
disp(ttestResultsAcc);

% Optional: Save to CSV
% writetable(ttestResultsAcc, 'pairwise_ttests_accuracy_all_conditions.csv');


%% =======New Figure
%% NEW SECTION: Accuracy by Condition × TaskType (Sham2 Removed, Custom Order)

% STEP 1: Filter only desired conditions
customConds = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryAcc_filtered = summaryAcc(ismember(string(summaryAcc.Condition), customConds), :);

% STEP 2: Sort conditions and tasks
summaryAcc_filtered.Condition = categorical(string(summaryAcc_filtered.Condition), customConds, 'Ordinal', true);
summaryAcc_filtered = sortrows(summaryAcc_filtered, {'Condition', 'TaskType'});

% STEP 3: Create combined CondTask label
summaryAcc_filtered.CondTask = strcat(string(summaryAcc_filtered.Condition), " / ", string(summaryAcc_filtered.TaskType));

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

    idx = summaryAcc_filtered.CondTask == label;
    y = summaryAcc_filtered.mean_Correct(idx);
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
ylabel('Accuracy (Proportion Correct)');
%title('Accuracy by Condition × TaskType (Sham2 Removed)');
ylim([0.4 1.05]);
grid on;

%% 
%% NEW SECTION: Summary Table for Reporting Accuracy (Condition × TaskType)

% Use the filtered dataset with Sham2 removed
customConds = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryAcc_filtered = summaryAcc(ismember(string(summaryAcc.Condition), customConds), :);

% Preallocate result table
reportTable = table();

row = 1;
for cond = customConds
    for task = ["2", "3"]
        % Filter matching rows
        idx = (summaryAcc_filtered.Condition == cond) & (summaryAcc_filtered.TaskType == task);
        accValues = summaryAcc_filtered.mean_Correct(idx);

        % Skip if no data
        if isempty(accValues)
            continue;
        end

        % Compute stats
        N = numel(accValues);
        meanAcc = mean(accValues);
        sdAcc = std(accValues);
        semAcc = sdAcc / sqrt(N);

        % Save row
        reportTable(row,:) = table( ...
            string(cond), string(task), N, meanAcc, sdAcc, semAcc, ...
            'VariableNames', {'Condition', 'TaskType', 'N', 'MeanAccuracy', 'SD', 'SEM'} ...
        );
        row = row + 1;
    end
end

% Display the table
disp('------------------------------');
disp('Accuracy Summary Table (for Reporting):');
disp(reportTable);

% Optional: Save to CSV
% writetable(reportTable, 'accuracy_summary_table.csv');
