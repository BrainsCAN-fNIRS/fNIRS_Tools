% fNIRSTools_bids_util_plotIndivFourier(bids_info, input_suffix, output_suffix, freq_range, time_start_end)
%
% Inputs:
%   bids_info       struct          no default          bids_info structure specifying datasets to use
%                                                       Modes:
%                                                       	1. Single dataset to plot it directly
%                                                       	2. Multiple datasets from one participant to plot their mean and 95%CI
%                                                       	3. Multiple datasets from multiple participants to plot mean and 95%CI of participant means
%                                                           	(weight by participant, not by dataset)
%
%   input_suffix    char            no default          Suffix for reading data
%
%   output_suffix   char/nan        default=nan         Suffix to add to output (defaults to the input_suffix)
%
%   freq_range      1x2 numeric     default=[0 inf]     Frequency range to display
%
%   time_start_end  1x2 numeric     default[-inf +inf]  Start/end time to select samples
%
function plotIndivFourier(bids_info, input_suffix, output_suffix, freq_range, time_start_end)

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    output_suffix = input_suffix;
end
if output_suffix(1)~='_';
    output_suffix = ['_' output_suffix];
end

if ~exist('freq_range', 'var')
    freq_range = [0 inf];
end

if ~exist('time_start_end', 'var')
    time_start_end = [-inf +inf];
end

%% Output Folder

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'plotIndivFourier' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% Run Each
fig = figure('Position', get(0,'ScreenSize'));
for ds = 1:bids_info.number_datasets
    %load
    data = fNIRSTools.bids.io.readFile(bids_info, input_suffix, ds);
    name = strrep([bids_info.datasets(ds).full_name output_suffix],'_','\_');
    
    %calc fourier
    [power,freq] = fNIRSTools.internal.CalcFourier(data, freq_range, time_start_end);
    
    %get channels
    [channels,has_sdc_info] = fNIRSTools.internal.GetChannels(data);
    
    %number rows/cols
    number_channels = height(channels);
    nrow = ceil(sqrt(number_channels));
    if (nrow * (nrow-1)) >= number_channels
        ncol = nrow - 1;
    else
        ncol = nrow;
    end
    
    %draw each channel
    for c = 1:number_channels
        subplot(nrow,ncol,c)
        plot(freq, power(:,channels.TypeIndices{c}));
        xlim(freq([1 end]));
        
        lbl = sprintf('S%02d-D%02d', channels.source(c), channels.detector(c));
        if has_sdc_info && channels.ShortSeperation(c)
            lbl = [lbl ' (SDC)'];
        end
        
        title(lbl);
    end
    
    %main title
    sgtitle(name);
    
    %image of figure
    F = getframe(gcf);
    img = F.cdata;
    
    %invert
    img = 255 - img;

    %remove whitespace
    fgd = mean(img - img(1,1,:), 3) > 20;
    x = find(any(fgd,1));
    y = find(any(fgd,2));
    img = img( (y(1)-20) : (y(end)+20) , (x(1)-20) : (x(end)+20) , :);

    %save
    imwrite(img, [directory bids_info.datasets(ds).full_name output_suffix '.png']);
end
close(fig);

