% ---------------------------------------------
% STEP 1: Relabel conditions (A/B/C/D → 4Hz/Phase)
% ---------------------------------------------
allTrials.Condition(allTrials.Condition == "A") = "4Hz45";
allTrials.Condition(allTrials.Condition == "B") = "7Hz45";
allTrials.Condition(allTrials.Condition == "C") = "7Hz315";
allTrials.Condition(allTrials.Condition == "D") = "4Hz315";

% ---------------------------------------------
% STEP 2: Filter valid trials and compute subject-level means
% ---------------------------------------------
validTrials = allTrials(~isnan(allTrials.Correct) & allTrials.Correct ~= -1, :);

summaryRT = varfun(@mean, validTrials, ...
    'InputVariables', 'Latency', ...
    'GroupingVariables', {'SubjectID', 'Condition'});

% Define custom condition order and enforce it
condOrder = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1", "Sham2"];
summaryRT.Condition = categorical(string(summaryRT.Condition), condOrder, 'Ordinal', true);
condOrder_cat = categorical(condOrder, condOrder, 'Ordinal', true);

% Get x-axis positions for plotting
[~, xPos] = ismember(summaryRT.Condition, condOrder_cat);
summaryRT = sortrows(summaryRT, 'Condition');

conds = categories(summaryRT.Condition);

% ---------------------------------------------
% STEP 3: Plot Box + Jittered Scatter
% ---------------------------------------------
figure; hold on;

% Define colors
redColor = [1, 0, 0];           % Active conditions
blueColor = [0.2, 0.4, 1];      % Sham conditions

for i = 1:length(conds)
    cond = conds{i};
    idx = summaryRT.Condition == cond;
    y = summaryRT.mean_Latency(idx);

    % Add jitter for scatter
    x_jitter = 0.15 * randn(sum(idx), 1) + i;

    % Set color
    if contains(cond, 'Sham')
        boxColor = blueColor;
    else
        boxColor = redColor;
    end

    % Scatter points
    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);

    % Boxplot
    boxchart(repmat(i, sum(idx), 1), y, ...
        'BoxFaceColor', boxColor, ...
        'BoxFaceAlpha', 0.3, ...
        'LineWidth', 1.5, ...
        'MarkerStyle', 'none');
end

% Final touches
set(gca, 'XTick', 1:length(conds), 'XTickLabel', conds, 'FontSize', 12);
ylabel('Mean Reaction Time (s)');
xtickangle(45);
title('Reaction Time by Condition (Box + Scatter)');
ylim([0.3 1]);
grid on;


%% ANOVA for Reaction time

%% STEP 4: Repeated-Measures ANOVA Using fitlme
summaryRT.SubjectID = categorical(summaryRT.SubjectID);
summaryRT.Condition = categorical(summaryRT.Condition, condOrder, 'Ordinal', true);
lme = fitlme(summaryRT, 'mean_Latency ~ Condition + (1|SubjectID)');

anovaResults = anova(lme);
disp('------------------------------');
disp('Repeated-Measures ANOVA Results (fitlme):');
disp(anovaResults);

%% STEP 5: Post-hoc Pairwise Comparisons Using anovan + multcompare
% Convert to long format again
subjects = summaryRT.SubjectID;
conditions = summaryRT.Condition;
latency = summaryRT.mean_Latency;

% Run simple repeated-measures ANOVA (Subject = random factor)
[p, tbl, stats] = anovan(latency, {conditions, subjects}, ...
    'random', 2, ...                       % Subject is random
    'model', 'linear', ...                 % Main effect only
    'varnames', {'Condition', 'Subject'});

% Post-hoc pairwise comparisons (on Condition only)
disp('------------------------------');
disp('Post-hoc Pairwise Comparisons (Tukey-Kramer):');
figure;
posthoc = multcompare(stats, 'Dimension', 1);  % 1 = Condition


%% Two-by-Tow t-test

% Get list of unique conditions
conds = categories(summaryRT.Condition);
nConds = length(conds);

% Initialize results table
results = table();

% Loop over all unique condition pairs
row = 1;
for i = 1:nConds-1
    for j = i+1:nConds
        cond1 = conds{i};
        cond2 = conds{j};

        % Extract paired data
        data1 = summaryRT.mean_Latency(summaryRT.Condition == cond1);
        data2 = summaryRT.mean_Latency(summaryRT.Condition == cond2);
        subjects1 = summaryRT.SubjectID(summaryRT.Condition == cond1);
        subjects2 = summaryRT.SubjectID(summaryRT.Condition == cond2);

        % Match subjects (ensure proper alignment)
        [commonSubs, i1, i2] = intersect(subjects1, subjects2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        % Run paired t-test
        [~, p, ~, stats] = ttest(paired1, paired2);

        % Store results
        results(row,:) = table(string(cond1), string(cond2), p, stats.tstat, stats.df, ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df'});
        row = row + 1;
    end
end

% Display results
disp('------------------------------');
disp('Pairwise Paired t-Tests Between Conditions:');
disp(results);

% Optional: Export to CSV
% writetable(results, 'pairwise_ttests_reaction_time.csv');


%% NEW SECTION: Custom Reaction Time Plot (4 Active Conditions + Sham1 Only)
%% UPDATED SECTION: Custom RT Plot Excluding Max from 7Hz315

% STEP 1: Filter only selected conditions
selectedConditions = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1"];
customRT = summaryRT(ismember(string(summaryRT.Condition), selectedConditions), :);

% STEP 2: Remove the max value from 7Hz315
isTarget = string(customRT.Condition) == "7Hz315";
[~, maxIdx] = max(customRT.mean_Latency(isTarget));  % index within the 7Hz315 subset

% Translate to index in full table
targetIndices = find(isTarget);
customRT(targetIndices(maxIdx), :) = [];  % remove the row

% STEP 3: Reorder & re-categorize condition labels
customOrder = ["4Hz45", "7Hz45", "4Hz315", "7Hz315", "Sham1"];
customRT.Condition = categorical(string(customRT.Condition), customOrder, 'Ordinal', true);
customRT = sortrows(customRT, 'Condition');
customConds = categories(customRT.Condition);

% STEP 4: Plot
figure; hold on;
redColor = [1, 0, 0];           % Active conditions
blueColor = [0.2, 0.4, 1];      % Sham1

for i = 1:length(customConds)
    cond = customConds{i};
    idx = customRT.Condition == cond;
    y = customRT.mean_Latency(idx);
    x_jitter = 0.15 * randn(sum(idx), 1) + i;

    boxColor = strcmp(cond, "Sham1") * blueColor + ~strcmp(cond, "Sham1") * redColor;

    scatter(x_jitter, y, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.4);

    boxchart(repmat(i, sum(idx), 1), y, ...
        'BoxFaceColor', boxColor, ...
        'BoxFaceAlpha', 0.3, ...
        'LineWidth', 1.5, ...
        'MarkerStyle', 'none');
end

set(gca, 'XTick', 1:length(customConds), 'XTickLabel', customConds, 'FontSize', 12);
ylabel('Mean Reaction Time (s)');
xtickangle(45);
%title('RT (No Max in 7Hz315): 4 Active + Sham1');
ylim([0.3 1]);
grid on;

%% STEP 5: Pairwise Paired t-Tests (After Removing Max from 7Hz315)

% Get unique conditions from filtered dataset
conds = categories(customRT.Condition);
nConds = length(conds);

% Initialize results table
ttestResultsFiltered = table();
row = 1;

for i = 1:nConds-1
    for j = i+1:nConds
        cond1 = conds{i};
        cond2 = conds{j};

        % Extract data for both conditions
        data1 = customRT.mean_Latency(customRT.Condition == cond1);
        data2 = customRT.mean_Latency(customRT.Condition == cond2);
        subs1 = customRT.SubjectID(customRT.Condition == cond1);
        subs2 = customRT.SubjectID(customRT.Condition == cond2);

        % Find matching subjects
        [commonSubs, i1, i2] = intersect(subs1, subs2);
        paired1 = data1(i1);
        paired2 = data2(i2);

        if length(commonSubs) < 3
            continue;  % skip underpowered comparisons
        end

        [~, p, ~, stats] = ttest(paired1, paired2);

        ttestResultsFiltered(row,:) = table(...
            string(cond1), string(cond2), ...
            p, stats.tstat, stats.df, length(commonSubs), ...
            'VariableNames', {'Condition1', 'Condition2', 'pValue', 'tStat', 'df', 'nSubjects'});

        row = row + 1;
    end
end

% Display results
disp('------------------------------');
disp('Two-by-Two Paired t-Tests (after removing max from 7Hz315):');
disp(ttestResultsFiltered);

% Optional: Save to file
% writetable(ttestResultsFiltered, 'pairwise_ttests_filtered.csv');

%% 
%% STEP 6: Summary Table for Reporting Reaction Time by Condition

% Use full summaryRT table including all 6 conditions
reportRTTable = table();
row = 1;

conds_for_table = categories(summaryRT.Condition);  % Already sorted

for i = 1:length(conds_for_table)
    cond = conds_for_table{i};

    % Filter rows
    rtVals = summaryRT.mean_Latency(summaryRT.Condition == cond);

    if isempty(rtVals)
        continue;
    end

    % Compute stats
    N = numel(rtVals);
    meanRT = mean(rtVals);
    sdRT = std(rtVals);
    semRT = sdRT / sqrt(N);

    % Store in table
    reportRTTable(row,:) = table( ...
        string(cond), N, meanRT, sdRT, semRT, ...
        'VariableNames', {'Condition', 'N', 'MeanRT', 'SD', 'SEM'} ...
    );
    row = row + 1;
end

% Display result
disp('------------------------------');
disp('Summary Table: Reaction Time by Condition');
disp(reportRTTable);

% Optional: Save to CSV
% writetable(reportRTTable, 'reaction_time_summary_table.csv');

