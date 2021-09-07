% fNIRSTools_bids_util_plotIndivChannels(bids_info, input_suffix, output_suffix, normalize)
%
% Inputs:
%   bids_info       struct          no default      bids_info structure specifying datasets to use
%                                                   Modes:
%                                                       1. Single dataset to plot it directly
%                                                       2. Multiple datasets from one participant to plot their mean and 95%CI
%                                                       3. Multiple datasets from multiple participants to plot mean and 95%CI of participant means
%                                                           (weight by participant, not by dataset)
%
%   input_suffix    char            no default      Suffix for reading data
%
%   output_suffix   char/nan        default=nan     Suffix to add to output (defaults to the input_suffix)
%
%   normalize       logical         default=false   Normalizes timeseries by their variance
function plotIndivChannels(bids_info, input_suffix, output_suffix, normalize)

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    output_suffix = input_suffix;
end

if ~exist('normalize', 'var') || isempty(normalize)
    normalize = false;
end

%% Output Folder

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'plotIndivChannels' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% Run Each
fig = figure('Position', get(0,'ScreenSize'));
for ds = 1:bids_info.number_datasets
    %load
    data = fNIRSTools.bids.io.readFile(bids_info, input_suffix, ds);
    name = strrep(bids_info.datasets(ds).full_name,'_','\_');
    
    %normalize?
    if normalize
        data.data = data.data ./ nanvar(data.data);
        name = [name ' (normalized)'];
    end
    
    %channels
    sd = unique(data.probe.link{:,1:2}, 'rows');
    number_channels = size(sd,1);
    
    %row/col
    nrow = ceil(sqrt(number_channels));
    if (nrow * (nrow-1)) >= number_channels
        ncol = nrow - 1;
    else
        ncol = nrow;
    end
    nrow = nrow + 2;
    
    %clear
    clf
    
    %draw all channels together
    subplot(nrow,ncol,[1 ncol*2]);
    plot(data.time,data.data);
    xlim([data.time(1) data.time(end)])
    
    %add each channels
    for c = 1:number_channels
        subplot(nrow,ncol,(ncol*2)+c);
        ind = find((data.probe.link.source==sd(c,1)) & (data.probe.link.detector==sd(c,2)));
        plot(data.time,data.data(:,ind));
        xlim([data.time(1) data.time(end)])
        
        types = data.probe.link.type(ind);
        if ~iscell(types)
            types = arrayfun(@num2str, types, 'UniformOutput', false);
        end
        
        title(sprintf('S%d-D%d (index: %s)', sd(c,1), sd(c,2), num2str(ind')));
    end
    
    %main title
    sgtitle(name);
    
    %save
    saveas(fig, [directory bids_info.datasets(ds).full_name output_suffix '.png']);
end
close(fig);
