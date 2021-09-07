% fNIRSTools_bids_util_plotIndivChannels(bids_info, input_suffixes, output_suffix)
%
% Inputs:
%   bids_info       struct          no default      bids_info structure specifying datasets to use
%                                                   Modes:
%                                                       1. Single dataset to plot it directly
%                                                       2. Multiple datasets from one participant to plot their mean and 95%CI
%                                                       3. Multiple datasets from multiple participants to plot mean and 95%CI of participant means
%                                                           (weight by participant, not by dataset)
%
%   input_suffixes  {char}          no default      Suffixes for reading data file sets
%
%   output_suffix   char/nan        default=nan     Suffix to add to output (no suffix if nan)
function plotIndivChannels(bids_info, input_suffixes, output_suffix)

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    output_suffix = '';
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
    data = fNIRSTools.bids.io.readFile(bids_info, input_suffixes, ds);
    
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
    plot(data.data);
    xlim([data.time(1) data.time(end)])
    
    %add each channels
    for c = 1:number_channels
        subplot(nrow,ncol,(ncol*2)+c);
        ind = find((data.probe.link.source==sd(c,1)) & (data.probe.link.detector==sd(c,2)));
        plot(data.data(:,ind));
        xlim([data.time(1) data.time(end)])
        
        types = data.probe.link.type(ind);
        if ~ischar(types)
            types = arrayfun(@num2str, types, 'UniformOutput', false);
        end
        
        title(sprintf('S%d-D%d (index: %s)', sd(c,1), sd(c,2), num2str(ind')));
    end
    
    %main title
    sgtitle(strrep(bids_info.datasets(ds).full_name,'_','\_'));
    
    %save
    saveas(fig, [directory bids_info.datasets(ds).full_name output_suffix '.png']);
end
close(fig);
