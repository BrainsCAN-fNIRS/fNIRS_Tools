% applyMergedMontage(bids_info, input_data_suffix, input_montage_suffixe, output_suffix, skip_if_exists)
%
% Inputs:
%   bids_info                       struct          no default      bids_info structure specifying datasets to use
%
%   input_data_suffix               char            no default      Suffix for reading data files
%
%   input_montage_suffixe           char            no default      Suffix for reading merged montage file
%
%   output_suffix                   char/nan        default=nan     Suffix to add to output (defaults to input_montage_suffixe)
%
%   skip_if_exists                  logical         default=false   If true, skip datasets where output already exists
function applyMergedMontage(bids_info, input_data_suffix, input_montage_suffixe, output_suffix, skip_if_exists)

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    output_suffix = input_montage_suffixe;
end

if ~exist('skip_if_exists', 'var') || isempty(skip_if_exists) || isnan(skip_if_exists)
    skip_if_exists = false;
end

%% Prep Output

directory = [bids_info.root_directory 'derivatives' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% Load Montage Info

fprintf('Loading merged montage info...\n');
montage = load([directory 'MergeMontage_' input_montage_suffixe '.mat']);

%% Apply To Data

fprintf('Loading data...\n');
all_data = fNIRSTools.bids.io.readFile(bids_info, input_data_suffix);

%% Output Filepaths (same order as data array)

[filepaths_output,exists_output] = fNIRSTools.bids.io.getFilepath(output_suffix, bids_info, true);

%% Process

fprintf('Applying merged montage...\n');
for d = 1:bids_info.number_datasets
    fprintf('\tDataset %d of %d: %s\n', d, bids_info.number_datasets, bids_info.datasets(d).full_name);
    if exists_output(d) && skip_if_exists
        fprintf('\t\tAlready exists, skipping!\n');
        continue
    else
        data = all_data(d);
        
        %clear what we are about to reorder just to be safe
        data.data(:) = nan;
        
        %set probe
        data.probe = montage.probe;
        
        %combine old s/d pos
        %5 col: xyz is_source index
        ns = size(all_data(d).probe.srcPos,1);
        nd = size(all_data(d).probe.detPos,1);
        old_pos = [all_data(d).probe.srcPos true(ns,1) (1:ns)'; all_data(d).probe.detPos false(nd,1) (1:nd)'];
        
        %populate channel data
        for c = 1:height(data.probe.link)
            %what we're looking for in original montage (2D)
            target_pos = [data.probe.srcPos(data.probe.link.source(c),:);
                          data.probe.detPos(data.probe.link.detector(c),:)];
            type = data.probe.link.type(c);
            
            %init
            ind_source = nan;
            ind_detector = nan;
            
            %find
            for i = 1:2
                dists = sqrt(sum(abs(old_pos(:,1:3) - target_pos(i,:)) .^ 2, 2));
                [min_dist,min_ind] = nanmin(dists);
                if min_dist > montage.distance_threshold_2D
                    %did not find
                    continue
                end
                if old_pos(min_ind,4)
                    ind_source = old_pos(min_ind,5);
                else
                    ind_detector = old_pos(min_ind,5);
                end
            end
            
            %confirm both found
            if isnan(ind_source) || isnan(ind_detector)
                continue
            end
            
            %find channel in old probe link
            ind_channel = find(all_data(d).probe.link.source==ind_source & all_data(d).probe.link.detector==ind_detector & all_data(d).probe.link.type==type);
            if length(ind_channel) ~= 1
                continue
            end
            
            %copy channel data
            data.data(:,c) = all_data(d).data(:,ind_channel);
            
        end
        
        %save
        save(filepaths_output{d}, 'data')
        
    end
end

