% Define the directory where the Excel files are stored
dataDir = '/Volumes/ExtremeSSD2/BBRF_round2/ORIGINAL_analysis/BehavioralData';

% Get a list of all Excel files in the directory
files = dir(fullfile(dataDir, '*.xlsx'));

% Remove macOS hidden metadata files like ._Sub01_Session01_A.xlsx
files = files(~startsWith({files.name}, '._'));

% Initialize an empty structured array
allData = struct('FileName', {}, 'SubjectID', {}, 'SessionID', {}, 'Condition', {}, 'Data', {});

% Loop through each file and read the data
for i = 1:length(files)
    filePath = fullfile(dataDir, files(i).name);

    try
        dataTable = readtable(filePath, 'PreserveVariableNames', true);
    catch ME
        warning('Error reading file %s: %s', files(i).name, ME.message);
        continue;
    end

    % Use a more robust regular expression
    % Matches: Sub02_Session01_A.xlsx
    tokens = regexp(files(i).name, '^Sub(\d+)_Session(\d+)_([A-Z]+|Sham)\.xlsx$', 'tokens');

    if ~isempty(tokens)
        subjectID = str2double(tokens{1}{1});
        sessionID = str2double(tokens{1}{2});
        condition = tokens{1}{3};
    else
        warning('Filename format not matched: %s', files(i).name);
        subjectID = NaN;
        sessionID = NaN;
        condition = 'Unknown';
    end

    allData(end+1).FileName = files(i).name;
    allData(end).SubjectID = subjectID;
    allData(end).SessionID = sessionID;
    allData(end).Condition = condition;
    allData(end).Data = dataTable;
end

% Save the data
save('all_behavioral_data_ORIGINAL.mat', 'allData');
disp('All files have been read and stored successfully.');
