% bids_info = fNIRSTools_bids_io_getBIDSInfo(root_directory, subject_number, run_number, task_name, session_number)
%
% Returns "bids_info" structure, which is required by most functions in this package.
%
% Arguments:
%   root_directory      char        no default      path to BIDS project directory (can be relative or absolute)
%
%   task_name           string      default=fNIRS   name of task to include in filenames
%
%   subject_number      [int]/nan   default=nan     subjects to select or nan to select all
%
%   run_number          [int]/nan   default=nan     runs to select or nan to select all
%
%   session_number      [int]/nan   default=nan     sessions to select or nan to select all
%
%   multi_select        logical     default=true    allow selection of multiple datasets        
%
function [bids_info] = fNIRSTools_bids_io_getBIDSInfo(root_directory, task_name, subject_number, run_number, session_number, multi_select)

%% Set Defaults

if ~exist('subject_number', 'var')
    subject_number = nan;
end

if ~exist('run_number', 'var')
    run_number = nan;
end

if ~exist('task_name', 'var')
    task_name = 'fNIRS';
end

if ~exist('session_number', 'var')
    session_number = nan;
end

if ~exist('multi_select', 'var')
    multi_select = true;
end

%% Check Values

if ~exist('root_directory', 'var')
    error('root_directory is required')
end

CheckArgument('root_directory',root_directory,'char');
CheckArgument('subject_number',subject_number,{'int' 'nan'});
CheckArgument('run_number',run_number,{'int' 'nan'});
CheckArgument('task_name',task_name,'char');
CheckArgument('session_number',session_number,{'int' 'nan'});
CheckArgument('multi_select',multi_select,'logical');

%% Fix Directory Path for Current OS

%end with filesep
if root_directory(end) ~= filesep
    root_directory(end+1) = filesep;
end

%correct filesep for current OS
root_directory( arrayfun(@(c) (c=='\')|(c=='/'), root_directory) ) = filesep;

%make project directory
if ~exist(root_directory, 'dir')
    try
        mkdir(root_directory);
    catch err
        warning('Failed to create missing project directory: %s', root_directory)
        rethrow(err)
    end
end

%store directory
bids_info.root_directory = root_directory;

%% Select Datasets

if ~isnan(subject_number)
    subjects = arrayfun(@(s) sprintf('sub-%02d',s), subject_number, 'UniformOutput', false);
else
    list = dir([bids_info.root_directory 'sub-*']);
    list = list([list.isdir]);
    subjects = {list.name};
end

if isempty(subjects)
    error('No subjects found in project directory!')
end

for sub = subjects
    sub = sub{1};
    fol_sub = [bids_info.root_directory sub filesep];

    if ~isnan(session_number)
        sessions = arrayfun(@(s) sprintf('ses-%02d',s), session_number, 'UniformOutput', false);
    else
        list = dir([fol_sub 'ses-*']);
        list = list([list.isdir]);
        sessions = {list.name};
    end

    if isempty(sessions), continue, end
    for ses = sessions
        ses = ses{1};
        fol_ses_func = [fol_sub ses filesep 'func' filesep];

        if ischar(task_name)
            tasks = {['task-' task_name]};
        else
            list = dir([fol_ses_func '*_task-*_*.snirf']);
            tasks = unique(cellfun(@(x) x.task, regexp({list.name}, '_(?<task>task-\w+)_', 'names'), 'UniformOutput', false));
        end

        if isempty(tasks), continue, end
        for task = tasks
            task = task{1};

            if ~isnan(run_number)
                runs = arrayfun(@(r) sprintf('run-%02d',r), run_number, 'UniformOutput', false);
            else
                list = dir([fol_ses_func sprintf('*_%s_*.snirf', task)]);
                runs = cellfun(@(x) ['run-' x], unique(cellfun(@(x) x.run, regexp({list.name}, '_run-(?<run>\d+)_', 'names'), 'UniformOutput', false)), 'UniformOutput', false);
            end

            if isempty(runs), continue, end
            for run = runs
                run = run{1};
                info = struct('subject', sub, ...
                              'session', ses, ...
                              'task', task, ...
                              'run', run, ...
                              'subject_number', str2num(sub(find(sub=='-')+1:end)), ...
                              'session_number', str2num(ses(find(ses=='-')+1:end)), ...
                              'task_name', task(find(task=='-')+1:end), ...
                              'run_number', str2num(run(find(run=='-')+1:end)), ...
                              'full_name', sprintf('%s_%s_%s_%s_fNIRS', sub, ses, task, run));
                if ~isfield(bids_info,'datasets')
                    bids_info.datasets = info;
                else
                    bids_info.datasets(end+1) = info;
                end
            end

        end

    end
end

%% Check Selection

%found anything?
if ~isfield(bids_info,'datasets')
    error('No datasets were found/selected')
end

%counts
bids_info.number_datasets = length(bids_info.datasets);
bids_info.subject_numbers = unique([bids_info.datasets.subject_number]);
bids_info.subject_count = length(bids_info.subject_numbers);
bids_info.run_counts = arrayfun(@(s) length([bids_info.datasets([bids_info.datasets.subject_number] == s).run_number]), bids_info.subject_numbers);
bids_info.run_count_max = max(bids_info.run_counts);
bids_info.run_count_min = min(bids_info.run_counts);

%multiple?
if (bids_info.number_datasets > 1) && ~multi_select
    error('Found %d datasets but multi_select is off', bids_info.number_datasets)
end

%% Load first file and get some extra info

%use raw if available (faster) else snirf
type_found = 'raw';
[~, exists] = fNIRSTools.bids.io.getFilepath(type_found, bids_info);
if ~any(exists)
    type_found = 'snirf';
    [~, exists] = fNIRSTools.bids.io.getFilepath(type_found, bids_info);
end

%get info from first dataset
if any(exists)
    ind = find(exists, 1, 'first');
    data = fNIRSTools.bids.io.readFile(bids_info, type_found, ind, false, false);
    bids_info.first_condition_set = data.stimulus.keys;
    bids_info.first_channel_set = unique(data.probe.link(:,1:2),'rows');
    bids_info.first_source_count = size(data.probe.srcPos, 1);
    bids_info.first_detector_count = size(data.probe.detPos, 1);
else
    bids_info.first_condition_set = cell(0);
    bids_info.first_channel_set = [];
    bids_info.first_source_count = nan;
    bids_info.first_detector_count = nan;
end

%count conditions
bids_info.first_condition_set_count = length(bids_info.first_condition_set);
bids_info.first_channel_set_count = size(bids_info.first_channel_set, 1);




%%
function CheckArgument(field, value, valid_types)

%value
if iscell(value)
    error('Cell values are not valid for: %s', field)
elseif isempty(value)
    error('Empty values are not valid for: %s', field)
end

%value type
if ~iscell(valid_types)
    valid_types = {valid_types};
end
any_valid = false;
for type = valid_types
    type = type{1};
    switch type
        case 'char'
            any_valid = any_valid || ischar(value);
            
        case 'int'
            any_valid = any_valid || (isnumeric(value) && ~any(isnan(value)) && ~any(~IsInt(value)));
            
        case 'nan'
            any_valid = any_valid || (isnumeric(value) && any(isnan(value)));
            
        case 'logical'
            any_valid = any_valid || islogical(value);
            
        otherwise
            error('Unsupported check type: %s', type)
    end
end
if ~any_valid
    error('Invalid data type in: %s', field)
end

function [isint] = IsInt(value)
if ~isnumeric(value) || (length(value)~=1)
    isint = false;
else
    isint = (value == floor(value));
end