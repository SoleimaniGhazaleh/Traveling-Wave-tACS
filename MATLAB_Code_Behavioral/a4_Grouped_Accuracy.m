%% ACCURACY ANALYSIS
% ---------------------------------------------
% STEP 1: Filter and compute subject-level accuracy
% ---------------------------------------------
validTrials = allTrials(~isnan(allTrials.Correct) & allTrials.Correct ~= -1, :);

summaryAcc = varfun(@mean, validTrials, ...
    'InputVariables', 'Correct', ...
    'GroupingVariables', {'SubjectID', 'Condition'});

% Define condition order and enforce
condOrder = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryAcc.Condition = categorical(string(summaryAcc.Condition), condOrder, 'Ordinal', true);
summaryAcc = sortrows(summaryAcc, 'Condition');
conds = categories(summaryAcc.Condition);

%% STEP 2: Plot Accuracy (Box + Jittered Scatter)
figure; hold on;
redColor = [1, 0, 0];
blueColor = [0.2, 0.4, 1];

for i = 1:length(conds)
    cond = conds{i};
    idx = summaryAcc.Condition == cond;
    y = summaryAcc.mean_Correct(idx);
    x_jitter = 0.15 * randn(sum(idx), 1) + i;

    % Color logic
    if contains(cond, 'Sham')
        boxColor = blueColor;
    else
        boxColor = redColor;
    end

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
    boxchart(repmat(i, sum(idx), 1), y, ...
        'BoxFaceColor', boxColor, ...
        'BoxFaceAlpha', 0.3, ...
        'LineWidth', 1.5, ...
        'MarkerStyle', 'none');
end

set(gca, 'XTick', 1:length(conds), 'XTickLabel', conds, 'FontSize', 12);
ylabel('Accuracy (Proportion Correct)');
%title('Accuracy by Condition');
ylim([0.4 1]);
grid on;

%% STEP 3: Repeated-Measures ANOVA (fitlme)
summaryAcc.SubjectID = categorical(summaryAcc.SubjectID);
summaryAcc.Condition = categorical(summaryAcc.Condition, condOrder, 'Ordinal', true);
lme_acc = fitlme(summaryAcc, 'mean_Correct ~ Condition + (1|SubjectID)');

anovaResultsAcc = anova(lme_acc);
disp('------------------------------');
disp('Repeated-Measures ANOVA for Accuracy (fitlme):');
disp(anovaResultsAcc);

%% STEP 4: Post-hoc Pairwise Comparisons (anovan + multcompare)
subjects = summaryAcc.SubjectID;
conditions = summaryAcc.Condition;
accuracy = summaryAcc.mean_Correct;

[pAcc, tblAcc, statsAcc] = anovan(accuracy, {conditions, subjects}, ...
    'random', 2, ...
    'model', 'linear', ...
    'varnames', {'Condition', 'Subject'});

disp('------------------------------');
disp('Post-hoc Pairwise Comparisons (Tukey-Kramer):');
figure;
posthocAcc = multcompare(statsAcc, 'Dimension', 1);  % Condition = 1

%% STEP 5: Pairwise Paired t-tests for Accuracy
resultsAcc = table();
row = 1;
for i = 1:length(conds)-1
    for j = i+1:length(conds)
        cond1 = conds{i};
        cond2 = conds{j};

        data1 = summaryAcc.mean_Correct(summaryAcc.Condition == cond1);
        data2 = summaryAcc.mean_Correct(summaryAcc.Condition == cond2);
        subs1 = summaryAcc.SubjectID(summaryAcc.Condition == cond1);
        subs2 = summaryAcc.SubjectID(summaryAcc.Condition == cond2);

        [commonSubs, i1, i2] = intersect(subs1, subs2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        [~, p, ~, stats] = ttest(paired1, paired2);

        resultsAcc(row,:) = table(string(cond1), string(cond2), p, stats.tstat, stats.df, ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df'});
        row = row + 1;
    end
end

disp('------------------------------');
disp('Pairwise Paired t-Tests for Accuracy:');
disp(resultsAcc);

% Optionally export
% writetable(resultsAcc, 'pairwise_ttests_accuracy.csv');



%% ACCURACY: Plot & Paired t-tests after Removing Max from 7Hz315

% STEP 1: Filter only selected conditions
selectedConditions = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1"];
customAcc = summaryAcc(ismember(string(summaryAcc.Condition), selectedConditions), :);

% STEP 2: Remove max accuracy from 7Hz315
isTargetAcc = string(customAcc.Condition) == "7Hz315";
[~, maxIdxAcc] = max(customAcc.mean_Correct(isTargetAcc));  % index within 7Hz315 subset
targetIndicesAcc = find(isTargetAcc);
customAcc(targetIndicesAcc(maxIdxAcc), :) = [];  % remove it

% STEP 3: Reorder & re-categorize conditions
customOrderAcc = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1"];
customAcc.Condition = categorical(string(customAcc.Condition), customOrderAcc, 'Ordinal', true);
customAcc = sortrows(customAcc, 'Condition');
customCondsAcc = categories(customAcc.Condition);

% STEP 4: Plot
figure; hold on;
redColor = [1, 0, 0];           % Active
blueColor = [0.2, 0.4, 1];      % Sham1

for i = 1:length(customCondsAcc)
    cond = customCondsAcc{i};
    idx = customAcc.Condition == cond;
    y = customAcc.mean_Correct(idx);
    x_jitter = 0.15 * randn(sum(idx), 1) + i;

    boxColor = strcmp(cond, "Sham1") * blueColor + ~strcmp(cond, "Sham1") * redColor;

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);

    boxchart(repmat(i, sum(idx), 1), y, ...
        'BoxFaceColor', boxColor, ...
        'BoxFaceAlpha', 0.3, ...
        'LineWidth', 1.5, ...
        'MarkerStyle', 'none');
end

set(gca, 'XTick', 1:length(customCondsAcc), 'XTickLabel', customCondsAcc, 'FontSize', 12);
ylabel('Accuracy (Proportion Correct)');
title('Accuracy (No Max in 7Hz315): 4 Active + Sham1');
ylim([0.3 1.05]);
grid on;

%% STEP 5: Pairwise Paired t-Tests for Accuracy (After Removing Max)

conds = categories(customAcc.Condition);
nConds = length(conds);
ttestResultsAccFiltered = table();
row = 1;

for i = 1:nConds-1
    for j = i+1:nConds
        cond1 = conds{i};
        cond2 = conds{j};

        data1 = customAcc.mean_Correct(customAcc.Condition == cond1);
        data2 = customAcc.mean_Correct(customAcc.Condition == cond2);
        subs1 = customAcc.SubjectID(customAcc.Condition == cond1);
        subs2 = customAcc.SubjectID(customAcc.Condition == cond2);

        [commonSubs, i1, i2] = intersect(subs1, subs2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        if length(commonSubs) < 3
            continue;
        end

        [~, p, ~, stats] = ttest(paired1, paired2);

        ttestResultsAccFiltered(row,:) = table(...
            string(cond1), string(cond2), ...
            p, stats.tstat, stats.df, length(commonSubs), ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df', 'nSubjects'});

        row = row + 1;
    end
end

disp('------------------------------');
disp('Accuracy: Two-by-Two Paired t-Tests (after removing max from 7Hz315):');
disp(ttestResultsAccFiltered);

% Optional: Save results
% writetable(ttestResultsAccFiltered, 'pairwise_ttests_accuracy_filtered.csv');
%% 
%% STEP 6: Summary Table for Reporting Accuracy by Condition

% Compute reporting stats (including Sham1 and Sham2)
reportAccTable = table();
row = 1;

conds_for_table = categories(summaryAcc.Condition);  % already sorted

for i = 1:length(conds_for_table)
    cond = conds_for_table{i};

    % Filter data
    accVals = summaryAcc.mean_Correct(summaryAcc.Condition == cond);

    % Skip if empty
    if isempty(accVals)
        continue;
    end

    % Compute stats
    N = numel(accVals);
    meanAcc = mean(accVals);
    sdAcc = std(accVals);
    semAcc = sdAcc / sqrt(N);

    % Store row
    reportAccTable(row,:) = table( ...
        string(cond), N, meanAcc, sdAcc, semAcc, ...
        'VariableNames', {'Condition', 'N', 'MeanAccuracy', 'SD', 'SEM'} ...
    );

    row = row + 1;
end

% Display
disp('------------------------------');
disp('Summary Table: Accuracy by Condition');
disp(reportAccTable);

% Optional: save to file
% writetable(reportAccTable, 'accuracy_summary_table_all_conditions.csv');
