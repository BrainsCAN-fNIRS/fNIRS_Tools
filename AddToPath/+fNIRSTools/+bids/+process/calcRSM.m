% data = fNIRSTools_bids_process_calcRSM(bids_info, source_type, output_type, channels, conditions, split, select_oxy_dexoy)
%
% Calculates RSM for each dataset, combines dataset RSMs into subject RSMs,
% and collects all subject RSMs into a group file.
%
% Inputs:
%   bids_info           struct          no default      bids_info structure specifying datasets to use
%
%   source_type         char            no default      Suffix for reading GLM files (must contain beta field)
%
%   output_type         char/nan        default=nan     Suffix to add to output (auto-generated if nan)
%
%   channels            [Nx2 int]/nan   default=nan     Nx2 of source/detector pairs or SD table. If NaN, selects all channels.
%
%   conditions          {char}/nan      default/nan     List of conditions in order to include. If NaN, uses all conditions.
%
%   split               logical/nan     default=nan     If true, subject RSMs will be the average of all even dataset splits (diag != 1).
%                                                       Otherwisw, all datasetes are combined (diag == 1). NaN defaults to true.
%                                                       In either case, the final matrices will be symmetrical.        
%
%   select_oxy_dexoy    char/nan        default=nan     Options:
%                                                           OXY or HBO: oxy only, 
%                                                           DEOXY or HBR: deoxy only
%                                                           SPLIT: oxy and deoxy split into two conditions
%                                                           COMBINE: oxy and deoxy concatenated for first level correlation (default)
%
function [data] = fNIRSTools_bids_process_calcRSM(bids_info, source_type, output_type, channels, conditions, split, select_oxy_dexoy)

%% Defaults

%split
if ~exist('split', 'var') || isnan(split)
    split = true;
end
if split
    split_name = 'SPLIT';
    if bids_info.run_count_min == 1
        error('SPLIT mode is not valid because one or more subjects have only one run')
    end
else
    split_name = 'NONSPLIT';
end
    
%oxy/deoxy
if ~exist('select_oxy_dexoy', 'var') || isnumeric(select_oxy_dexoy)
    select_oxy_dexoy = 'COMBINE';
else
    select_oxy_dexoy = upper(select_oxy_dexoy);
    if ~any(strcmp(select_oxy_dexoy, {'OXY' 'HBO' 'DEOXY' 'HBR' 'SPLIT' 'COMBINE'}))
        error('select_oxy_dexoy must be one of the following: OXY HBO DEOXY HBR SPLIT COMBINE')
    end
end

%channels
if ~exist('channels', 'var') || numel(channels) < 2
    channels = bids_info.first_channel_set;
elseif size(channels,2) > 2
    error('Invalid channels input')
else
    if ~istable(channels)
        channels = array2table(channels,'VariableNames',{'source','detector'});
    end
    %verify that these channels exist
    if any(arrayfun(@(s,d) ~any((bids_info.first_channel_set.source == s) & (bids_info.first_channel_set.detector == d)), channels.source, channels.detector))
        error('One or more specified channel does not exist in the montage') 
    end
end
number_channels = size(channels, 1);
if ~number_channels
    error('No channels were specified')
end

%conditions
if ~exist('conditions', 'var') || isnumeric(conditions)
    conditions = bids_info.first_condition_set;
else
    if ischar(conditions)
        conditions = {conditions};
    end
    if any(cellfun(@(c) ~any(strcmp(bids_info.first_condition_set, c)), conditions))
        error('One or more specified conditions is not present')
    end
end
number_conditions = length(conditions);
if number_conditions < 2
    error('Less than 2 conditions were specified')
end

%target suffix
if ~exist('output_type', 'var') || isnumeric(output_type)
    output_type = sprintf('%s_RSM-%s-%s-%dChannel-%dCond', source_type, split_name, select_oxy_dexoy, number_channels, number_conditions);
end


%% Load Data

fprintf('Loading data...\n');
data_source = fNIRSTools.bids.io.readFile(bids_info, source_type);


%% Data Has Beta
if ~any(strcmp(fields(data_source(1)), 'beta'))
    error('Input data does not contain "beta" field');
end


%% Confirm Same Montage / Conditions

if bids_info.number_datasets > 1
    fprintf('Checking montages...\n');
    txt = evalc('same_montage = fNIRSTools.bids.util.checkMontages(bids_info, false, data_source);');
    if ~same_montage
        error('Datasets do not have the same montage')
    end
    
    fprintf('Checking conditions...\n');
    txt = evalc('same_conditions = fNIRSTools.bids.util.checkConditions(bids_info, nan, data_source);');
    if ~same_conditions
        error('Datasets do not have the same conditions')
    end
end


%% Prep

channel_selection = arrayfun(@(s,d) any(channels.source==s & channels.detector==d), data_source(1).variables.source, data_source(1).variables.detector);
ind_oxy = cell2mat(cellfun(@(c) find(channel_selection & strcmp(data_source(1).variables.type, 'hbo') & strcmp(data_source(1).variables.cond, c)), conditions, 'UniformOutput', false));
ind_deoxy = cell2mat(cellfun(@(c) find(channel_selection & strcmp(data_source(1).variables.type, 'hbr') & strcmp(data_source(1).variables.cond, c)), conditions, 'UniformOutput', false));
switch select_oxy_dexoy
    case {'OXY' 'HBO'}
        cond.names = conditions;
        cond.inds = ind_oxy;
    case {'DEOXY' 'HBR'}
        cond.names = conditions;
        cond.inds = ind_deoxy;
    case 'SPLIT'
        cond.names = [cellfun(@(c) sprintf('%s-Oxy', c), conditions, 'UniformOutput', false) cellfun(@(c) sprintf('%s-Deoxy', c), conditions, 'UniformOutput', false)];
        cond.inds = [ind_oxy ind_deoxy];
    case 'COMBINE'
        cond.names = conditions;
        cond.inds = [ind_oxy; ind_deoxy];
    otherwise
        error('Unsupported select_oxy_dexoy value: %s', select_oxy_dexoy)
end
cond.count = length(cond.names);


%% Calculate Single-Dataset RSMs

fprintf('Calculating RSMs per subject...\n');
data.subject_rsms = nan(cond.count, cond.count, bids_info.subject_count);
for s = 1:bids_info.subject_count
    sid = bids_info.subject_numbers(s);
    
    %find datasets
    ind_datasets = find([bids_info.datasets.subject_number] == sid);
    
    %display
    fprintf('\t%d of %d: %s\n', s, bids_info.subject_count, bids_info.datasets(ind_datasets(1)).subject);
    
    %betas is [channels x cond x run]
    betas = cell2mat(permute(arrayfun(@(ind) data_source(ind).beta(cond.inds), ind_datasets, 'UniformOutput', false),[1 3 2]));
    
    %calculate RSM
    data.subject_rsms(:,:,s) = CalcRSM(betas, split);
end

%mean across subjects
data.mean_rsm = mean(data.subject_rsms, 3);


%% Save

%store some more info
data.betas = betas;
data.conditions = cond.names;
data.conditions_count = length(cond.names);
data.probe = data_source(1).probe;
data.source_type = source_type;
data.channels = channels;
data.split = split;
data.select_oxy_dexoy = select_oxy_dexoy;

%save
filepath_output = [bids_info.root_directory 'derivatives' filesep sprintf('Group_%s.mat', output_type)];
fprintf('Saving: %s\n', filepath_output);
save(filepath_output, 'data')


%% Done

disp Done.



%%
function [rsm] = CalcRSM(betas, split)
if ~split
    betas = PrepBetas(PrepBetas);
    rsm = corr(betas, 'type', 'Pearson');
else
    %count
    [~, number_conds, number_runs] = size(betas);
    
    %full set of splits
    selections = combnk(1:number_runs, floor(number_runs/2));
    number_splits = size(selections, 1);
    selected = cell2mat(arrayfun(@(x) arrayfun(@(y) any(selections(x,:) == y), 1:number_runs), 1:number_splits, 'UniformOutput', false)');
    
    %restrict to the "unique splits" - i.e., don't include [1 2 3] and [4 5 6] (opposite pairs) in a 6 run set
    %THE FULL SET OF SPLITS IS STILL USED, but only the unique half are computed
    %and then the final matrix is averaged with its transposition (more efficient)
    for i = number_splits:-1:1
        if any(~any(selected(1:(i-1),:) ~= ~selected(i,:), 2))
            selected(i,:) = [];
        end
    end
    number_splits = size(selected, 1);
    
    %init
    rsms = nan(number_conds, number_conds, number_splits);
    
    %calc
    for split = 1:number_splits
        %gather
        betas_set1 = betas(:, :, selected(split,:));
        betas_set2 = betas(:, :, ~selected(split,:));
        
        %mean/deamean individually
        betas_set1 = PrepBetas(betas_set1);
        betas_set2 = PrepBetas(betas_set2);
        
        %corr
        rsms(:,:,split) = corr(betas_set1, betas_set2, 'type', 'Pearson');
    end
    
    %average across split
    rsm = nanmean(rsms, 3);
    
    %average across diag (because redundant selections were not explicitly
    %calculated)
    rsm = arrayfun(@(a,b) nanmean([a b]), rsm, rsm');
end


function [betas] = PrepBetas(betas)
%average across runs
betas = nanmean(betas, 3);
%demean across conditions within each channel (separate for oxy/deoxy)
betas = betas - mean(betas,2);