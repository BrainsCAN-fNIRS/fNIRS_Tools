%[all_identical] = fNIRSTools_bids_util_checkConditions(bids_info, expected_conditions, data)
%
% Reads all snirf files (or *_RAW.mat if available) and check if they have
% the same conditions. Names, case, and  order must all be identical.
% 
% Outputs:
%   all_identical           logical     indicates whether all datasets had the same conditions
%
% Inputs:
%   expected_conditions     {char}      default=nan         when not nan, throws an error if the condition set does not match this
%
%   data                    [struct]    no default          can optionally pass data to avoid reloading
%
function [all_identical] = fNIRSTools_bids_util_checkConditions(bids_info, expected_conditions, data)

%% Inputs

if exist('expected_conditions', 'var') && ~isnumeric(expected_conditions)
    if ~iscell(expected_conditions)
        expected_conditions = {expected_conditions};
    end
    if ~compareConditionSets(bids_info.first_condition_set, expected_conditions)
        fprintf('Expected Conditions:\t%s\n', sprintf('%s\t', expected_conditions{:}));
        fprintf('Actual Conditions:\t%s\n', sprintf('%s\t', bids_info.first_condition_set{:}));
        error('Specified datasets do not match the expected condition list')
    end
end


%% Read Conditions

%read data if not provided
if ~exist('data', 'var')
    %if all runs have raw or HB mat, it's much faster to get montages from there
    [~,exists_raw] = fNIRSTools.bids.io.getFilepath('RAW', bids_info, true);
    if ~any(~exists_raw)
        data = fNIRSTools.bids.io.readFile(bids_info, 'RAW');
    else
        warning('Did not locate full set of raw mat files. Reading directly from SNIRF instead, which is slower.')
        data = fNIRSTools.bids.io.readFile(bids_info, 'SNIRF');
    end
end

if any(strcmp(fields(data), 'stimulus')) %isfield doesn't work for AnalyzIR data
    conditions = arrayfun(@(f) f.stimulus.keys, data, 'UniformOutput', false);
elseif any(strcmp(fields(data), 'conditions')) %isfield doesn't work for AnalyzIR data
    conditions = arrayfun(@(f) f.conditions', data, 'UniformOutput', false);
else
    error('Data does not contain "stimulus" or "conditions" field');
end
number_conditions = length(conditions);
if number_conditions < 2
    error('Found less than 2 datasets')
end

%% Compare

fprintf('Comparing conditions...\n');
    
conditions_ref = conditions{1};
same = [true; cellfun(@(c) compareConditionSets(conditions_ref, c), conditions(2:end))];

conditions_matche_first = [{bids_info.datasets.full_name}' num2cell(same)];
disp 'Results of comparison to first condition set (1=same, 0=diff):'
fprintf('First Condition Set:\t%s\n', sprintf('%s\t', conditions_ref{:}));
disp(conditions_matche_first)

all_identical = ~any(~same(:));
if ~all_identical
    warning('Conditions are not all identical')
end


function [same] = compareConditionSets(source, target)
if length(source) ~= length(target)
    same = false;
elseif any(~cellfun(@strcmp, source, target))
    same = false;
else
    same = true;
end