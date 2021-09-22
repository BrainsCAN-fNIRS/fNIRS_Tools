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
if output_suffix(1) ~= '_'
    output_suffix = ['_' output_suffix];
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
colour_channel = [0.2 0.2 0.2];

x_ratio = 0.5;
y_ratio = 0.25;

%% Run Each
screen_size = get(0,'ScreenSize');
fig = figure('Position', screen_size);
for ds = 1:bids_info.number_datasets
    %load
    data = fNIRSTools.bids.io.readFile(bids_info, input_suffix, ds);
    name = strrep([bids_info.datasets(ds).full_name output_suffix],'_','\_');
    
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
    
    %determine subplots
    screen_width = range(screen_size([1 3])) + 1;
    screen_height = range(screen_size([2 4])) + 1;
    screen_ratio = screen_width / screen_height;
    nrow = 100;
    ncol = round(nrow * screen_ratio);
    nrow_top = max(1, floor(nrow/10));
    ncell_top_end = nrow_top * ncol;
    ncell_bot_start = ncell_top_end + (ncol*5) + 1;
    ncell = nrow * ncol;
    
    %draw all channels together
    subplot(nrow,ncol,[1 ncell_top_end]);
    plot(data.time,data.data);
    xlim([data.time(1) data.time(end)])
    xlabel('Time (sec)')
    ylabel('Intensity')
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');

    %draw montage view
    subplot(nrow,ncol,[ncell_bot_start ncell]);
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');
    
    %scale positions to match distances
    dist_pos = pdist([data.probe.srcPos(data.probe.link.source(1),:); data.probe.detPos(data.probe.link.detector(1),:)]);
    dist_actual = data.probe.distances(1);
    scale_pos = dist_actual / dist_pos;
    srcPos = data.probe.srcPos * scale_pos;
    detPos = data.probe.detPos * scale_pos;
    
    %start hold
    hold on
    
    %draw channel connections
    for s = 1:size(srcPos,1)
        plot(srcPos(s,1),srcPos(s,2),'.','Color',colour_source)
    end
    for d = 1:size(detPos,1)
        plot(detPos(d,1),detPos(d,2),'.','Color',colour_detector)
    end
    
    %distances
    mean_dist = mean(data.probe.distances);
    plot_width = mean_dist * x_ratio;
    plot_height = mean_dist * y_ratio;
    template_x = linspace(-plot_width/2, +plot_width/2, length(data.time));
    
    %draw channel plots
    for c = 1:number_channels
        s = sd(c,1);
        d = sd(c,2);
        xy_s = srcPos(s,1:2);
        xy_d = detPos(d,1:2);
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
    
    %draw source/detectors labels
    for s = 1:size(srcPos,1)
        text(srcPos(s,1),srcPos(s,2),sprintf('S%d',s),'Color',colour_source)
    end
    for d = 1:size(detPos,1)
        text(detPos(d,1),detPos(d,2),sprintf('D%d',d),'Color',colour_detector)
    end
    
    %end hold
    hold off
    
    %no axis on montage view
    axis square
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
