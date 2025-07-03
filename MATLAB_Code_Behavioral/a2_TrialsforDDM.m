clear all
close all

% Load the data
load('all_behavioral_data_ORIGINAL.mat');

% Initialize final trial-level table
allTrials = table();

% Loop over each subject/session/condition
for i = 1:length(allData)
    subjectID = allData(i).SubjectID;
    sessionID = allData(i).SessionID;
    conditionRaw = string(allData(i).Condition); 
    
    dataTable = allData(i).Data;

    % Detect required columns
    totalBlocksCol = contains(dataTable.Properties.VariableNames, 'TotalBlocks', 'IgnoreCase', true);
    taskTypeCol    = contains(dataTable.Properties.VariableNames, 'values.N', 'IgnoreCase', true);
    trialCodeCol   = contains(dataTable.Properties.VariableNames, 'trialcode', 'IgnoreCase', true);
    responseCol    = contains(dataTable.Properties.VariableNames, 'response', 'IgnoreCase', true);
    latencyCol     = contains(dataTable.Properties.VariableNames, 'latency', 'IgnoreCase', true);

    % Skip files missing required columns
    if ~any([totalBlocksCol, taskTypeCol, trialCodeCol, responseCol, latencyCol])
        warning('Skipping %s: missing required columns.', allData(i).FileName);
        continue;
    end

    % Extract columns
    totalBlocks = dataTable{:, find(totalBlocksCol)};
    taskTypes   = string(dataTable{:, find(taskTypeCol)});
    trialCodes  = string(dataTable{:, find(trialCodeCol)});
    responses   = dataTable{:, find(responseCol)};
    latencies   = dataTable{:, find(latencyCol)};  % in ms

    nTrials = height(dataTable);

    % Metadata columns
    subjectCol   = repmat(subjectID, nTrials, 1);
    sessionCol   = repmat(sessionID, nTrials, 1);

    % Handle Sham condition renaming
    if conditionRaw == "Sham"
        condition = sprintf('Sham%d', sessionID);
        phaseCol = repmat("Sham", nTrials, 1);
        frequencyCol = repmat("Sham", nTrials, 1);
    else
        condition = conditionRaw;
        switch condition
            case "A", phaseCol = repmat("45", nTrials, 1); frequencyCol = repmat("4Hz", nTrials, 1);
            case "B", phaseCol = repmat("45", nTrials, 1); frequencyCol = repmat("7Hz", nTrials, 1);
            case "C", phaseCol = repmat("315", nTrials, 1); frequencyCol = repmat("7Hz", nTrials, 1);
            case "D", phaseCol = repmat("315", nTrials, 1); frequencyCol = repmat("4Hz", nTrials, 1);
            otherwise, phaseCol = repmat("Unknown", nTrials, 1); frequencyCol = repmat("Unknown", nTrials, 1);
        end
    end

    conditionCol = repmat(string(condition), nTrials, 1);

    % Determine correctness (200–1000 ms window)
    correctCol = NaN(nTrials, 1);
    for row = 1:nTrials
        if latencies(row) >= 200 && latencies(row) <= 1000
            if trialCodes(row) == "target" && responses(row) == 112
                correctCol(row) = 1;
            elseif trialCodes(row) == "nontarget" && responses(row) == 176
                correctCol(row) = 1;
            else
                correctCol(row) = 0;
            end
        end
    end

    % Convert latency to seconds
    latencies = latencies / 1000;

    % Create trial table
    trialTable = table(subjectCol, sessionCol, conditionCol, ...
        totalBlocks, taskTypes, trialCodes, responses, latencies, correctCol, ...
        phaseCol, frequencyCol, ...
        'VariableNames', {'SubjectID', 'SessionID', 'Condition', ...
        'BlockNumber', 'TaskType', 'TrialType', 'Response', 'Latency', 'Correct', ...
        'Phase', 'Frequency'});

    allTrials = [allTrials; trialTable];
end

% Save final trial-level table as CSV
writetable(allTrials, 'trial_level_data_with_phase_freq_mac.csv');
disp('✅ Trial-level data with Phase/Frequency saved successfully!');
