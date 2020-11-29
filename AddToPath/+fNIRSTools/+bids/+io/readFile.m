%[data] = fNIRSTools_bids_io_readFile(bids_info, type, selection, allow_missing, group)
function [data] = fNIRSTools_bids_io_readFile(bids_info, type, selection, allow_missing, group)

%% Inputs

type = upper(type);

%selection
%   nan=use all
%   ind=use that one index instead
if exist('selection', 'var') && ~isnan(selection) && (bids_info.number_datasets>1)
    bids_info = fNIRSTools.bids.io.getBIDSInfo(bids_info.root_directory, ...
                                             bids_info.datasets(selection).task_name, ...
                                             bids_info.datasets(selection).subject_number, ...
                                             bids_info.datasets(selection).run_number, ...
                                             bids_info.datasets(selection).session_number, ...
                                             false);
end

if ~exist('allow_missing', 'var')
    allow_missing = false;
end

if ~exist('group', 'var')
    group = false;
end

%% Find File(s)

if group
    filepaths = {[bids_info.root_directory filesep 'derivatives' filesep 'GROUP_' type '.mat']};
    exists = exist(filepaths{1}, 'file');
else
    [filepaths, exists] = fNIRSTools.bids.io.getFilepath(type, bids_info, true);
end

%stop if missing files
if any(~exists)
    if ~allow_missing
        error('One or more specified files does not exist and allow_missing is false')
    else
        %ignore missing files
        fprintf('Excluding %d missing files...\n', sum(exists <= 0));
        filepaths = filepaths(exists > 0);
    end
end

%any files?
number_files = length(filepaths);
if ~number_files
    error('No files were selected!')
end


%% Read File(s)

if length(bids_info) > 1
    fprintf('Reading %d files...\n', length(filepaths));
end

data = cellfun(@(fp) readSingleFile(fp, type), filepaths);


function [data] = readSingleFile(filepath, type)
if strcmp(type, 'SNIRF')
    data = nirs.io.loadSNIRF(filepath);

    %CORRECT RAW DATA DIMENSIONS IN RAW SNIRF READ
    if ~any((length(data.time) == size(data.data)) ~= [0 1])
        data.data = data.data';
    end
else
    text = evalc('data = load(filepath);'); %redirect messages
    data = data.data;
end

