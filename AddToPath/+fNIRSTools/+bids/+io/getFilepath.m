function [filepaths, exists] = analyzir_bids_io_getFilepath(type, bids_info, allow_multi_select, group)

%% Use First Dataset if Group

if ~exist('group', 'var')
    group = false;
end

if group
    bids_info = analyzir_bids.io.getBIDSInfo(bids_info.root_directory, ...
                                             bids_info.datasets(1).task_name, ...
                                             bids_info.datasets(1).subject_number, ...
                                             bids_info.datasets(1).run_number, ...
                                             bids_info.datasets(1).session_number, ...
                                             false);
end

%% Allow Multi?

if ~exist('allow_multi_select', 'var')
    allow_multi_select = true;
end

if ~allow_multi_select && (bids_info.number_datasets >1)
    error('bids_info contains multiple datasets but allow_multi_select is false')
end

%% Process

%init
filepaths = cell(bids_info.number_datasets, 1);
exists = nan(1, bids_info.number_datasets);

%run
for i = 1:bids_info.number_datasets
    [filepaths{i}, exists(i)] = getSingleFilepath(bids_info.root_directory, bids_info.datasets(i), type);
end

%% For single dataset, return filepath as char instead of {char}

if ~allow_multi_select
    filepaths = filepaths{1};
end



%% Subfunction
function [filepath,exists] =  getSingleFilepath(root_directory, dataset, type)

%% Common
subdir = sprintf('%s%s%s%sfunc%s', dataset.subject, filesep, dataset.session, filesep, filesep);

dir_main = [root_directory subdir];
dir_derivatives = [root_directory 'derivatives' filesep subdir];
dir_log = [root_directory 'log' filesep subdir];
dir_log_top = [root_directory 'log' filesep];

%% Generate
type = upper(type);
switch type
    case 'SNIRF'
        filepath = [dir_main dataset.full_name '.snirf'];
        
    case 'IMPORT_COND_COMPARISON_FIG'
        filepath = [dir_log_top 'Import' filesep dataset.full_name '_IMPORT-COND-COMPARISON-FIG.png'];
        
    case 'MONTAGE_COMPARISON_FIG'
        filepath = [dir_log_top 'MONTAGE-COMPARISON-FIG.png'];
        
    otherwise
        %custom type
        filepath = [dir_derivatives dataset.full_name '_' type '.mat'];
end

%% Make Directories
directory = filepath(1:find(filepath==filesep,1,'last'));
try
    if ~exist(directory, 'dir')
        mkdir(directory);
    end
catch err
    warning('Failed to create missing directory: %s', directory)
    rethrow(err)
end

%% File Already Exists?
exists = exist(filepath, 'file');
