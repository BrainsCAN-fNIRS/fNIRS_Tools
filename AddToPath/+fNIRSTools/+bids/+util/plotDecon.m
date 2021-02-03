% [fig] = fNIRSTools_bids_util_plotDecon(bids_info, file_suffix, output_suffix, channels, montage_mode, conditions, data_types, colours)
%
% Outputs:
%   fig             handle          (optional) return figure handle
%
% Inputs:
%   bids_info       struct          no default      bids_info structure specifying datasets to use
%                                                   Modes:
%                                                       1. Single dataset to plot it directly
%                                                       2. Multiple datasets from one participant to plot their mean and 95%CI
%                                                       3. Multiple datasets from multiple participants to plot mean and 95%CI of participant means
%                                                           (weight by participant, not by dataset)
%
%   input_suffix    char            no default      Suffix for reading decon GLM files
%
%   output_suffix   char/nan        default=nan     Suffix to add to output (auto-generated if nan)
%                   
%   channels        [Nx2 int]/nan   default=nan     Nx2 of source/detector pairs or SD table. If NaN, selects all channels.
%
%   montage_mode    logical/nan     default=true    Plot with montage view. If false, all channels are average for a single plot. (nan defaults to true)
%
%   conditions      {char}/nan      default=nan     Conditions to plot. If NaN, plot all.
%
%   data_types      char/nan        default=both    Can be set to both, oxy/hbo, or dexoy/hbr (nan defaults to both)
%
%   colours         [Nx3 num]/nan   default=nan     Colours for each condition. If NaN, then jet(#cond) will be used.
%
%   beta_range      num/nan         default=nan     Sets the min/max range of the y-axis (in beta units). If NaN, automatically select a reasonable range.
%
function [fig] = fNIRSTools_bids_util_plotDecon(bids_info, input_suffix, output_suffix, channels, montage_mode, conditions, data_types, colours, beta_range)

%% Defaults

if ~exist('output_suffix', 'var')
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    use_auto_suffix = true;
else
    use_auto_suffix = false;
end

if ~exist('montage_mode', 'var') || (isnumeric(montage_mode) && numel(montage_mode)==1 && isnan(montage_mode))
    montage_mode = true;
end

if ~exist('data_types', 'var') || (isnumeric(data_types) && numel(data_types)==1 && isnan(data_types))
    data_types = 'both';
end

%channels
if ~exist('channels', 'var') || numel(channels) < 2
    channels = bids_info.first_channel_set_LDC;
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
if ~number_conditions
    error('No conditions were specified')
end

if ~exist('colours', 'var')
    colours = nan;
end

%colours
if ~exist('colours', 'var') || ((numel(colours) == 1) && isnumeric(colours) && isnan(colours))
    %nan = use jet(#cond)
    colours = jet(number_conditions);
elseif (size(colours,2) ~= 3) || (size(colours,1) ~= number_conditions)
    error('Colours must be Nx3')
else
    if any((colours(:)<0) | (colours(:)>1))
        error('Colour values must be 0-to-1 RGB')
    end
end

%beta range
if ~exist('beta_range', 'var')
    beta_range = nan;
end


%% Process Inputs

%data types to plot
plot_oxy = any(strcmpi(data_types, {'both' 'oxy' 'hbo'}));
plot_deoxy = any(strcmpi(data_types, {'both' 'deoxy' 'hbr'}));

if ~plot_oxy && ~plot_deoxy
    error('Neither oxy or deoxy were selected.')
end


%% Load Data

fprintf('Loading data...\n');
data = fNIRSTools.bids.io.readFile(bids_info, input_suffix);


%% Confirm Same Montage / Conditions

if bids_info.number_datasets > 1
    fprintf('Checking montages...\n');
    txt = evalc('same_montage = fNIRSTools.bids.util.checkMontages(bids_info, false, data, true);');
    if ~same_montage
        error('Datasets do not have the same montage')
    end
    
    fprintf('Checking conditions...\n');
    txt = evalc('same_conditions = fNIRSTools.bids.util.checkConditions(bids_info, nan, data);');
    if ~same_conditions
        error('Datasets do not have the same conditions')
    end
end


%% Check Data

fprintf('Checking data...\n');

%count number bins used
number_timepoints = find(any(cell2mat(arrayfun(@(x) any(x.data,2), data, 'UniformOutput', false)'), 2), 1, 'last');

for i = 1:bids_info.number_datasets
    %set 0 to nan so they don't affect averages
    data(i).data(data(i).data==0) = nan;
    
    %remove unused time bins
    data(i).data = data(i).data(1:number_timepoints, :);
    data(i).time = data(i).time(1:number_timepoints);
end

%check same time bins in all datasets
if bids_info.number_datasets>1 && any(any(diff([data.time]')))
    error('Datasets did not use the same time bins');
end

%duration
times = data(1).time;
time_start = times(1);
time_end = times(end);
duration = (times(2)-times(1)) * length(times);

%check that datasets have requested conditions
if any(cellfun(@(c) ~any(strcmp(bids_info.first_condition_set, c)), conditions))
    error('Datasets do not contain all specified conditions')
end


%% Organize Data
%all decon cell matrices are [subject , channel , condition , deoxy/oxy]
%dimensions are maintained when averaging across subject/channel

fprintf('Reorganizing data...\n');

links = data(1).probe.link;
decon = cell(bids_info.subject_count, number_channels, number_conditions, 2);
for s = 1:bids_info.subject_count
    subject_number = bids_info.subject_numbers(s);
    ind = [bids_info.datasets.subject_number] == subject_number;
    
    data_sub = data(ind);
    
    for ch = 1:number_channels
        for co = 1:number_conditions
            for is_oxy = [false true]
                if is_oxy
                    type = ['hbo_' conditions{co}];
                else
                    type = ['hbr_' conditions{co}];
                end
                
                ind = find((links.source == channels.source(ch)) & (links.detector == channels.detector(ch)) & strcmp(links.type, type));
                if length(ind) ~= 1
                    error('Unexpected error during data organization (did not find exactly one match for source+detector+condition+type)')
                else
                    for d = data_sub'
                        decon{s,ch,co,1+is_oxy}(end+1,:) = d.data(:,ind)';
                    end
                end
            end
        end
    end
end

%participant mean and 95ci (across runs) 
decon_par_means = cellfun(@(d) nanmean(d,1), decon, 'UniformOutput', false);
decon_par_95ci = cellfun(@(d) Calc95CI(d), decon, 'UniformOutput', false);

%group mean and 95ci (across participant means)
[co,ch,od] = meshgrid(1:number_conditions,1:number_channels,1:2);
decon_group_input = permute(arrayfun(@(a,b,c) cell2mat(decon_par_means(:,a,b,c)), ch, co, od, 'UniformOutput', false), [4 1 2 3]);
decon_group_means = cellfun(@(d) nanmean(d,1), decon_group_input, 'UniformOutput', false);
decon_group_95ci = cellfun(@(d) Calc95CI(d), decon_group_input, 'UniformOutput', false);


%% Prep + What To Plot + Filepath

plot_eb_95ci = true;

%plot type
if montage_mode
    %plot each channel in montage view
    auto_suffix = sprintf('Montage-%dC', number_channels);
    plot_eb_95ci = false;
elseif number_channels > 1
    %plot mean of multiple channels in single view
    auto_suffix = sprintf('MeanChannel-%dC', number_channels);
    
    %average across channels
    [co,s,od] = meshgrid(1:number_conditions, 1:bids_info.subject_count, 1:2);
    decon_par_means = permute(arrayfun(@(a,b,c) nanmean(cell2mat(decon_par_means(a,:,b,c)'),1), s, co, od, 'UniformOutput', false), [1 4 2 3]);
    decon_par_95ci = permute(arrayfun(@(a,b,c) nanmean(cell2mat(decon_par_95ci(a,:,b,c)'),1), s, co, od, 'UniformOutput', false), [1 4 2 3]);
    [co,s,od] = meshgrid(1:number_conditions, 1, 1:2);
    decon_group_means = permute(arrayfun(@(a,b,c) nanmean(cell2mat(decon_group_means(a,:,b,c)'),1), s, co, od, 'UniformOutput', false), [1 4 2 3]);
    decon_group_95ci = permute(arrayfun(@(a,b,c) nanmean(cell2mat(decon_group_95ci(a,:,b,c)'),1), s, co, od, 'UniformOutput', false), [1 4 2 3]);
else
    %plot single channel in single view
    auto_suffix = sprintf('SingleChannel-S%dD%d', channels.source, channels.detector);
end

if use_auto_suffix
    output_suffix = auto_suffix;
end

%selection type
if bids_info.number_datasets == 1
    %single run
    filename = sprintf('%s_%s', bids_info.datasets(1).full_name, output_suffix);
    
    decon_means_use = decon_par_means;
    decon_95ci_use = [];
    plot_eb_95ci = false;
    
elseif bids_info.subject_count == 1
    %single subject
    filename = sprintf('%s_%s_%d-runs_%s', bids_info.datasets(1).subject, bids_info.datasets(1).task, bids_info.number_datasets, output_suffix);
    
    decon_means_use = decon_par_means;
    decon_95ci_use = decon_par_95ci;
else
    %group
    filename = sprintf('Group_%s_%d-subs_%d-runs_%s', bids_info.datasets(1).task, bids_info.subject_count, bids_info.number_datasets, output_suffix);
    
    decon_means_use = decon_group_means;
    decon_95ci_use = decon_group_95ci;
end

%decon dimensions at this point:
%   1. always 1 (was sinle run, or has been averaged across runs, or has
%                   been averaged across participant means)
%   2. #channel for montage mode otherwise 1 (averaged across channels)
%   3. #cond
%   4. 2 (deoxy/oxy)

%% Auto y-thresh (if beta_range=nan and montage_mode=true)

if isnan(beta_range) && montage_mode
    if plot_eb_95ci
        %need to fit beta+CI
        absmaxs = cellfun(@(b,ci) nanmax(abs(b)+ci), decon_means_use, decon_95ci_use);
    else
        %only need to fit beta
        absmaxs = cellfun(@(b) nanmax(abs(b)), decon_means_use);
    end
    beta_range = nanmean(absmaxs(:)) + (nanstd(absmaxs(:)) * 2);
    beta_range = round(beta_range, 1);
end

%% Plot

fprintf('Plotting: %s\n', auto_suffix);
fig = figure('Position', get(0,'ScreenSize'));

labels = cell(0);
counter = 0;
plots = [];

title_text = filename;

set(gcf,'color','k');
set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');
hold on

if montage_mode
    %% montage mode
    
    COLOUR_SOURCE = [0.5 0 0];
    COLOUR_DETECTOR = [0 0 0.5];
    COLOUR_SOURCE_LABEL = [1 0 0];
    COLOUR_DETECTOR_LABEL = [0 0 1];
    COLOUT_CHANNEL = [0.5 0.5 0.5];
    COLOUR_ZERO = [0.5 0.5 0.5];
    COLOUR_INVALID = [1 1 0];
    OPTODE_XY_MULT = 5000;
    PLOT_WIDTH = OPTODE_XY_MULT/10;
    PLOT_MAX_HEIGHT = OPTODE_XY_MULT/15;
    SDC_THRESH = OPTODE_XY_MULT/100;
    SDC_ADJUST = OPTODE_XY_MULT/50;
    LABEL_ADJUST = OPTODE_XY_MULT/25;
    OVERAP_THRESH = OPTODE_XY_MULT/20;
    
    title_text = sprintf('%s\n\n', title_text);
    
%     beta_range = nanmax(cell2mat(decon_means_use(:)')) - nanmin(cell2mat(decon_means_use(:)'));
%     beta_mult = beta_range / (OPTODE_XY_MULT*100000);
    
    %adjust position of overlapping SDC detectors
    xy_sources = data(1).probe.srcPos(:,1:2) * OPTODE_XY_MULT;
    xy_detectors = data(1).probe.detPos(:,1:2) * OPTODE_XY_MULT;
    for d = 1:size(xy_detectors, 1)
        diffs = abs(xy_sources - xy_detectors(d,:));
        dists = sqrt(sum(diffs .^ 2, 2));
        if any(dists < SDC_THRESH)
            xy_detectors(d,:) = xy_detectors(d,:) + [SDC_ADJUST SDC_ADJUST];
        end
    end
    
    %plot channel lines
    for c = 1:number_channels
        plot([xy_sources(channels.source(c),1) xy_detectors(channels.detector(c),1)], ...
             [xy_sources(channels.source(c),2) xy_detectors(channels.detector(c),2)], ...
             ':', 'Color', COLOUT_CHANNEL);
    end
    
    %plot source/detectors
    for s = unique(channels.source)'
        plot(xy_sources(s,1), xy_sources(s,2), 'o', 'MarkerSize', 3, 'MarkerEdgeColor', COLOUR_SOURCE, 'MarkerFaceColor', COLOUR_SOURCE); 
        plot(xy_sources(s,1), xy_sources(s,2) + LABEL_ADJUST, '.k', 'MarkerSize', 1); %ensure axis includes text
        text(xy_sources(s,1), xy_sources(s,2) + LABEL_ADJUST, sprintf('S%02d', s), 'Color', COLOUR_SOURCE_LABEL);
    end
    for d = unique(channels.detector)'
        plot(xy_detectors(d,1), xy_detectors(d,2), 'o', 'MarkerSize', 3, 'MarkerEdgeColor', COLOUR_DETECTOR, 'MarkerFaceColor', COLOUR_DETECTOR); 
        plot(xy_detectors(d,1), xy_detectors(d,2) + LABEL_ADJUST, '.k', 'MarkerSize', 1); %ensure axis includes text
        text(xy_detectors(d,1), xy_detectors(d,2) + LABEL_ADJUST, sprintf('D%02d', d), 'Color', COLOUR_DETECTOR_LABEL);
    end
    
    %calculate channel plot centers
    xy_channel = nan(number_channels, 2);
    for c = 1:number_channels
        xy_sd = [xy_sources(channels.source(c),:); xy_detectors(channels.detector(c),:)];
        center = mean(xy_sd, 1);
        
        diffs = abs(xy_channel - center);
        dists = sqrt(sum(diffs .^ 2, 2));
        [min_val,min_ind] = nanmin(dists);
        if ~isnan(min_val) && (min_val <= OVERAP_THRESH)
            center = xy_channel(min_ind,:);
        end
        
        xy_channel(c,:) = center;
    end
    
    %plot channels
    xs_standard = ((times - mean(times)) / duration * PLOT_WIDTH);
    for ch = 1:number_channels
        xs = xs_standard + xy_channel(ch,1);
        y = xy_channel(ch,2);
        
        plot([xs(1) xs(end)], [y y], '-', 'Color', COLOUR_ZERO);
        
        all_values = [decon_means_use{1,ch,:,:}];
%         r = range(all_values);
%         beta_mult = PLOT_HEIGHT / r;
%         beta_mult = 0.1;
        beta_mult = PLOT_MAX_HEIGHT / (beta_range * 2);
        
        for co = 1:number_conditions
            for is_oxy = [true false]
                if is_oxy
                    if ~plot_oxy, continue, end
                    style = '-';
                    type = 'oxy';
                else
                    if ~plot_deoxy, continue, end
                    style = ':';
                    type = 'deoxy';
                end
                
                ys = nanmax(-PLOT_MAX_HEIGHT,nanmin(PLOT_MAX_HEIGHT, (decon_means_use{1,ch,co,1+is_oxy} * beta_mult))) + y;
                if plot_eb_95ci
                    ys_95ci = nanmax(-PLOT_MAX_HEIGHT,nanmin(PLOT_MAX_HEIGHT, (decon_95ci_use{1,ch,co,1+is_oxy} * beta_mult))) + y;
                    this_plot = errorbar(xs, ys, ys_95ci, style, 'Color', colours(co,:));
                else
                    this_plot = plot(xs, ys, style, 'Color', colours(co,:));
                end
                
                if ch==1
                    counter = counter + 1;
                    labels{counter} = sprintf('%s %s', conditions{co}, type);
                    plots(counter) = this_plot;
                end
            end
        end
    end
    
    %draw HRF
    hrf = nirs.design.basis.Canonical;
    peak_time = hrf.peakTime;
    upshoot_time = hrf.uShootTime;
    peak_disp = hrf.peakDisp;
    upshoot_disp = hrf.uShootDisp;
    ratio  = hrf.ratio;
    values = hrf.getImpulseResponse(peak_time, peak_disp, upshoot_time, upshoot_disp, ratio, times);
    xs = xs_standard + min(xy_channel(:,1)) - PLOT_WIDTH*1.5; 
    y = max(xy_channel(:,2));
    plot([xs(1) xs(end)], [y y], ':', 'Color', COLOUR_ZERO);
    ys = y + (values / max(abs(values)) * PLOT_MAX_HEIGHT);
    this_plot = plot(xs, ys, '-', 'Color', COLOUR_ZERO);
    text(xs(1), y - LABEL_ADJUST, 'HRF', 'Color', COLOUR_ZERO);
    
    %display beta range
    text(xs(1), y + PLOT_MAX_HEIGHT + LABEL_ADJUST, sprintf('y-axis bounds +-%g', beta_range), 'Color', COLOUR_ZERO);
    
    axis image
    axis off
    
else
    %% single mode
    
    plot([time_start time_end], [0 0], '-w');
    
    for c = 1:number_conditions
        colour = colours(c,:);
        xoffset = (c - ((number_conditions+1)/2)) / 10;
        xs = times + xoffset;
        
        for is_oxy = [true false]
            if is_oxy
                if ~plot_oxy, continue, end
                style = '-';
                type = 'oxy';
            else
                if ~plot_deoxy, continue, end
                style = ':';
                type = 'deoxy';
            end
            
            counter = counter + 1;
            labels{counter} = sprintf('%s %s', conditions{c}, type);
            
            if plot_eb_95ci
                plots(counter) = errorbar(xs, decon_means_use{1,1,c,1+is_oxy}, decon_95ci_use{1,1,c,1+is_oxy}, style, 'Color', colour);
            else
                plots(counter) = plot(xs, decon_means_use{1,1,c,1+is_oxy}, style, 'Color', colour);
            end
            
        end
    end
    
    v = axis;
    axis([time_start time_end v(3:4)])
    
    if ~isnan(beta_range)
        v = axis;
        axis([v(1:2) -beta_range +beta_range])
    end
    
    set(gca,'xtick',times);
    grid on
    
    xlabel 'Time (sec)';
    ylabel 'Beta';
end

hold off
title(strrep(title_text,'_',' '), 'Color', 'w')
legend(plots, labels, 'TextColor', 'w', 'Location', 'EastOutside');


%% Save

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'decon' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end
filepath = [directory  filename '.png'];
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


%% Close Figure if Not Returning Handle
if ~nargout
    close(fig)
end




%returns N widths for X-by-N data (X samples)
function [width] = Calc95CI(data)
[H,P,CI] = ttest(data, 0, 'tail', 'both', 'alpha', 0.05);
width = range(CI)/2;