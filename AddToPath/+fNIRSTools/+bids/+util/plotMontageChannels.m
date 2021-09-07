% fNIRSTools_bids_util_plotMontageChannels(bids_info, input_suffix, output_suffix, normalize)
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
function plotMontageChannels(bids_info, input_suffix, output_suffix, normalize)

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

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'plotMontageChannels' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% Constants
colour_source = [1 0 0];
colour_detector = [0.25 0.25 1];
colour_channel = [0.1 0.1 0.1];

x_ratio = 0.7;
y_ratio = 0.3;

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
    
    %clear
    clf
    
    %colour
    set(gcf,'color','k');
    type_colours = jet(max([4 length(data.probe.types)]));
    type_colours = type_colours(end:-1:1,:);
    
    %draw all channels together
    subplot(6,6,[1 12]);
    plot(data.time,data.data);
    xlim([data.time(1) data.time(end)])
    xlabel('Time (sec)')
    ylabel('Intensity')
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');

    %draw montage view
    subplot(6,6,[13 36]);
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');
    
    %start hold
    hold on
    
    %draw source/detectors
    for s = 1:size(data.probe.srcPos,1)
        plot(data.probe.srcPos(s,1),data.probe.srcPos(s,2),'.','Color',colour_source)
        text(data.probe.srcPos(s,1),data.probe.srcPos(s,2),sprintf('S%d',s),'Color',colour_source)
    end
    for d = 1:size(data.probe.detPos,1)
        plot(data.probe.detPos(d,1),data.probe.detPos(d,2),'.','Color',colour_detector)
        text(data.probe.detPos(d,1),data.probe.detPos(d,2),sprintf('D%d',d),'Color',colour_detector)
    end
    
    %distances
    mean_dist = mean(data.probe.distances);
    plot_width = mean_dist * x_ratio;
    plot_height = mean_dist * y_ratio;
    template_x = linspace(-plot_width/2, +plot_width/2, length(data.time));
    
    %draw channels
    for c = 1:number_channels
        s = sd(c,1);
        d = sd(c,2);
        xy_s = data.probe.srcPos(s,1:2);
        xy_d = data.probe.detPos(d,1:2);
        xy_c = mean([xy_s; xy_d]);
        plot([xy_s(1) xy_d(1)], [xy_s(2) xy_d(2)], ':', 'Color', colour_channel);
        
        xs = template_x + xy_c(1);
        
        ind = find((data.probe.link.source==s) & (data.probe.link.detector==d));
        values = data.data(:,ind);
        values = values - nanmin(values(:));
        values = values / nanmax(values(:));
        ys = (values * plot_height) + xy_c(2) - (plot_height/2);
        for i = 1:size(values,2)
            plot(xs,ys(:,i),'Color',type_colours(i,:));
        end
    end
    
    %end hold
    hold off
    
    %no axis on montage view
    axis off

    %main title
    sgtitle(name,'color','w');
    
    %image of figure
    F = getframe(gcf);
    img = F.cdata;

    %remove whitespace
    fgd = mean(img - img(1,1,:), 3) > 20;
    x = find(any(fgd,1));
    y = find(any(fgd,2));
    img = img( (y(1)-20) : (y(end)+20) , (x(1)-20) : (x(end)+20) , :);

    %save
    imwrite(img, [directory bids_info.datasets(ds).full_name output_suffix '.png']);
end
close(fig);
