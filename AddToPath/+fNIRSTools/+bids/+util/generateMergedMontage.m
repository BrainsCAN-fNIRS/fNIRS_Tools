% [fig] = generateMergedMontage(bids_info, input_suffix, output_suffix, distance_threshold_2D, exclude_nonuniversal_channels, skip_if_exists)
%
% Reads the montages from selected data files and creates a merged montage.
% Process:
%   1. Identify unique optode locations (regardless of source/detector)
%   2. Identify pairs of unique locations which contain a channel in one or
%       more datasets.
%
% Outputs:
%   fig                             handle          (optional) return figure handle
%
% Inputs:
%   bids_info                       struct          no default      bids_info structure specifying datasets to use
%
%   input_suffix                    char            no default      Suffix for reading data files
%
%   output_suffix                   char/nan        default=nan     Suffix to add to output (auto-generated if nan)
%
%   distance_threshold_2D           double          default=0.01    Distance threshold for identifying unique 2D optode coordinates.
%
%   exclude_nonuniversal_channels   logical         default=false   If true, the merged montage will only contain channels 
%                                                                   that were present in all montages.
%
%   skip_if_exists                  logical         default=false   If true, then this function will stop early when the output
%                                                                   file already exists.
%
function [fig] = generateMergedMontage(bids_info, input_suffix, output_suffix, distance_threshold_2D, exclude_nonuniversal_channels, skip_if_exists)

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    use_auto_suffix = true;
else
    use_auto_suffix = false;
end

if ~exist('distance_threshold_2D', 'var') || ~(numel(distance_threshold_2D)==1 && isnumeric(distance_threshold_2D))
    distance_threshold_2D = 0.01;
end

if ~exist('exclude_nonuniversal_channels', 'var') || ~(numel(exclude_nonuniversal_channels)==1 && islogical(exclude_nonuniversal_channels))
    exclude_nonuniversal_channels = false;
end

if ~exist('skip_if_exists') || ~(numel(skip_if_exists)==1 && islogical(skip_if_exists))
    skip_if_exists = false;
end

%% Prep Output

directory = [bids_info.root_directory 'derivatives' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

if ~use_auto_suffix
    filepath_mat = [directory 'MergeMontage_' output_suffix '.mat'];
    if skip_if_exists && exist(filepath_mat, 'file')
        warning('Output already exists. Skipping!')
        fig = nan;
        return
    end
end


%% Load Data

fprintf('Loading data...\n');
data = fNIRSTools.bids.io.readFile(bids_info, input_suffix);
data_count = numel(data);


%% Auto Output Suffix

if use_auto_suffix
    output_suffix = sprintf('%s_MergeMontage-N%d-Thresh%g', input_suffix, numel(data), distance_threshold_2D);
    if exclude_nonuniversal_channels
        output_suffix = [output_suffix '-ExcludeNonUni'];
    end
    
    filepath_mat = [directory 'MergeMontage_' output_suffix '.mat'];
    if skip_if_exists && exist(filepath_mat, 'file')
        warning('Output already exists. Skipping!')
        fig = nan;
        return
    end
end


%% Find All Optode Locations

fprintf('Finding unique optode locations...\n');

locations = zeros(0,3);
locations3D = zeros(0,3);

for d = 1:data_count
    coords = [data(d).probe.detPos; data(d).probe.srcPos];
    coords3D = [data(d).probe.detPos3D; data(d).probe.srcPos3D];
    for c = 1:size(coords, 1)
        coord = coords(c,:);
        coord3D = coords3D(c,:);
        
        d = sqrt(sum((locations - coord) .^ [2 2 2], 2));
        if ~any(d<distance_threshold_2D);
            locations(end+1,:) = coord;
            locations3D(end+1,:) = coord3D;
        end
    end
end

locations_count = size(locations, 1);

%% Find All Channels (ignores source-detector direction)

fprintf('Finding unique channel location pairs...\n');

channels_counts = zeros(locations_count, locations_count);
channels_sdc = false(locations_count, locations_count);

for d = 1:data_count
    fprintf('\tProcessing set %d of %d...\n', d, data_count);
    
    if any(strcmp(data(d).probe.link.Properties.VariableNames,'ShortSeperation'))
        has_sdc_info = true;
        pairs = unique([data(d).probe.link.source data(d).probe.link.detector data(d).probe.link.ShortSeperation], 'rows');
        pairs = array2table(pairs,'VariableNames',{'Source' 'Detector' 'ShortSeperation'});
    else
        has_sdc_info = true;
        pairs = unique([data(d).probe.link.source data(d).probe.link.detector], 'rows');
        pairs = array2table(pairs,'VariableNames',{'Source' 'Detector'});
    end
    
    for p = 1:height(pairs)
        coord = data(d).probe.srcPos(pairs.Source(p),:);
        [~,ind1] = min(sqrt(sum((locations - coord) .^ [2 2 2], 2)));
        coord = data(d).probe.detPos(pairs.Detector(p),:);
        [~,ind2] = min(sqrt(sum((locations - coord) .^ [2 2 2], 2)));
        
        channels_counts(ind1,ind2) = channels_counts(ind1,ind2) + 1;
        channels_counts(ind2,ind1) = channels_counts(ind2,ind1) + 1;
        
        if has_sdc_info && pairs.ShortSeperation(p)
            channels_sdc(ind1,ind2) = true;
            channels_sdc(ind2,ind1) = true;
        end
    end
end

channels = channels_counts > 0;

self_channel_count = sum(channels(find(eye(locations_count))));
channels_count = (sum(channels(:)) + self_channel_count) / 2;

%% Fiducials

fid = [];
for d = data'
    fid = [fid; d.probe.optodes(contains(d.probe.optodes.Type, 'FID'), :)];
end
fid = unique(fid,'rows');

%% Probe

%signal types
types = unique(cell2mat(arrayfun(@(x) x.probe.types, data, 'UniformOutput', false)));

%units (assume all same)
units = data(1).probe.optodes.Units{1};

%init
probe = nirs.core.Probe1020;

%optodes
for otype = {'Source' 'Detector'}
    otype = otype{1};
    for o = 1:locations_count
        probe.optodes(end+1,:) = {sprintf('%s-%04d',otype,o) , locations(o,1) , locations(o,2) , locations(o,3) , otype , units};
    end
end

%fiducials
if ~isempty(fid)
    probe.optodes = [probe.optodes; fid];
end

%links
links = table([],[],[],[],'VariableNames',{'source','detector','type','ShortSeperation'});
for s = 1:locations_count
    for d = s:locations_count
        if channels(s,d)
            for type = types'
                links(end+1,:) = {s , d , type , channels_sdc(s,d)};
            end
        end
    end
end
probe.link = links;

%% Save Data

fprintf('Writing: %s\n', filepath_mat);
save(filepath_mat, 'locations', 'channels', 'channels_sdc', 'distance_threshold_2D', 'channels_counts', 'probe');


%% Figure

fig = figure('Position', get(0,'ScreenSize'));

plot3(locations3D(:,1),locations3D(:,2),locations3D(:,3),'w.')
grid on

count_min = min(channels_counts(channels_counts>0));
count_max = max(channels_counts(channels_counts>0));
count_range = count_max - count_min;
colours_precision = 100;
colours = [linspace(0,1,colours_precision)' linspace(0.5,0,colours_precision)' linspace(1,0,colours_precision)'];

hold on
    for i = 1:locations_count
        text(locations3D(i,1),locations3D(i,2),locations3D(i,3),num2str(i),'Color','w');
        for j = i:locations_count
            if channels(i,j)
                
                if channels_sdc(i,j)
                    style = '-';
                else
                    style = ':';
                end
                
                colour_ind = 1 + round((channels_counts(i,j) - count_min) / count_range * (colours_precision - 1));
                plot3(locations3D([i j],1),locations3D([i j],2),locations3D([i j],3),style,'Color',colours(colour_ind,:))
            end
        end
    end
hold off

axis image
axis off
cb = colorbar('Color','w');
ylabel(cb, 'Count', 'Color', 'w');
colormap(colours)
caxis([count_min count_max])

set(gca,'Color','k')
set(gcf,'Color', 'k')


%% Save Figure

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'MergeMontage' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end
filepath = [directory 'MergeMontage_' output_suffix '.png'];
fprintf('Writing: %s\n', filepath);

%image of figure
F = getframe(gcf);
img = F.cdata;

%remove whitespace
fgd = mean(img - img(1,1,:), 3) > 20;
x = find(any(fgd,1));
y = find(any(fgd,2));
img = img( (y(1)-20) : (y(end)+20) , (x(1)-20) : (x(end)+20) , :);

%save
imwrite(img, filepath);


%% Cleanup

if ~nargout
    close(fig)
end
