function fNIRSTools_bids_io_importNIRX(bids_info, data_directory, order_filepath, short_distance_threshold, print_prefix, extra_func)

%% Check BIDS Info
if bids_info.number_datasets ~= 1
    error('Requires bids_info that selects a single dataset')
end

%% Handle Inputs

if ~exist(data_directory, 'dir')
    error('Data directory does not exist: %s', data_directory)
end

if ~ischar(order_filepath)
    set_conditions = false;
else
    set_conditions = true;
    if ~exist(order_filepath, 'file')
        error('Order file does not exist: %s', order_filepath)
    end
end

if ~exist('print_prefix', 'var')
    print_prefix = '';
end

if exist('short_distance_threshold', 'var')
    identify_sdc = true;
else
    identify_sdc = false;
end

if exist('extra_func', 'var')
    do_extra_func = true;
else
    do_extra_func = false;
end

%% Output Filepath

%filepath
[filepath_snirf, exists_snirf] = fNIRSTools.bids.io.getFilepath('SNIRF', bids_info, false);
[filepath_raw, exists_raw] = fNIRSTools.bids.io.getFilepath('RAW', bids_info, false);

%already done?
if exists_snirf && exists_raw
    fprintf('%sOutput already exists, skipping import!\n', print_prefix);
    return
end

%delete prior if semi-complete
if exists_snirf
    delete(filepath_snirf);
end
if exists_raw
    delete(filepath_raw);
end

%% Read Data

fprintf('%sReading NIRx data...\n', print_prefix);
try
    try
        text = evalc('raw = nirs.io.loadNIRx(data_directory);'); %redirect messages
    catch
        text = evalc('raw = nirs.io.loadDirectory(data_directory);'); %redirect messages
    end
    duration = raw.time(end);
catch err
    warning('Read failed')
    if exist('text', 'var')
        warning(text);
    end
    rethrow(err)
end

%% Optional Extra Function

if do_extra_func
    raw = extra_func(raw);
end

%% Set Run Info

fprintf('%sAdding run info...\n', print_prefix);
raw.description = filepath_snirf(find(filepath_snirf==filesep,1,'last')+1:end-6);
raw.demographics('subject') = bids_info.datasets.subject;
raw.demographics('session') = bids_info.datasets.session;
raw.demographics('task') = bids_info.datasets.task;
raw.demographics('run') = bids_info.datasets.run;

%% Identify Short Separation Channels

if identify_sdc
    fprintf('%sIdentifying short-distance channels (threshold = %gmm)...\n', print_prefix, short_distance_threshold);
    
    job = nirs.modules.LabelShortSeperation;
    job.max_distance = short_distance_threshold;
    
    raw = job.run(raw);
end

%% Set Conditions

if set_conditions
    fprintf('%sSetting conditions...\n', print_prefix);
    
    
    %identify t0, all times are seconds relative to this (first trigger, if
    %no triggers then first sample)
    fprintf('%s\tLocating relative timepoint...', print_prefix);
    if raw.stimulus.count > 0
        trigger_times = cellfun(@(x) x.onset', raw.stimulus.values, 'UniformOutput', false);
        trigger_times = [trigger_times{:}];
        trigger_times = sort(trigger_times,'ascend');
        t0 = trigger_times(1);
        fprintf('found one or more trigger, using first as relative timepoint (t0 = %g)\n', t0);
    else
        t0 = 0; %first sample
        trigger_times = [];
        fprintf('no triggers found, using first sample as relative timepoint (t0 = %g)\n', t0);
    end
    
    
    fprintf('%s\tReading order file...\n', print_prefix);
    [xls_num,~,xls] = xlsread(order_filepath);
    last_row = find(~cellfun(@(x) length(x)==1 && isnan(x), xls(:,1)), 1, 'last');
    xls = xls(1:last_row,:);
    xls(6:end,5) = num2cell(xls_num(5:end,5));
    
    
    fprintf('%s\tParsing start and end times...\n', print_prefix);
    %note: TrimBaseline has some limitations, did not use it here
    %trim end
    time_end_base = xls{3,2};
    time_end = time_end_base + t0;
    frames_to_clear_end = find(raw.time > time_end);
    if ~isempty(frames_to_clear_end)
        fprintf('%s\tClearing last %d framess (relative timepoint %g + end time %g = %g)...\n', print_prefix, length(frames_to_clear_end), t0, time_end_base, time_end);
%         raw.data(frames_to_clear_end, :) = nan;
        raw.data(frames_to_clear_end, :) = [];
        raw.time(frames_to_clear_end) = [];
    end
    %trim start
    time_start_base = xls{2,2};
    time_start = time_start_base + t0;
    frames_to_clear_start = find(raw.time < time_start);
    if ~isempty(frames_to_clear_start)
        fprintf('%s\tClearing first %d framess (relative timepoint %g + start time %g = %g sec)...\n', print_prefix, length(frames_to_clear_start), t0, time_start_base, time_start);
%         raw.data(frames_to_clear_start, :) = nan;
        raw.data(frames_to_clear_start, :) = [];
        raw.time(frames_to_clear_start) = [];
    end
    
    
    fprintf('%s\tParsing order...\n', print_prefix);
    order = cell2table(xls(6:end, 1:5), 'VariableNames', xls(5,1:5));
    conds = unique(order.Condition);
    num_cond = length(conds);
    fprintf('%s\t\tFound %d trials\n', print_prefix, height(order));
    fprintf('%s\t\tFound %d conditions\n', print_prefix, num_cond);
    for c = 1:num_cond
        fprintf('%s\t\t\t%d: %s\n', print_prefix, c, conds{c});
    end
    
    
    fprintf('%s\tSetting conditions...\n', print_prefix);
    old_cond = raw.stimulus;
    new_cond = Dictionary;
    for c = 1:num_cond
        ind = find(strcmp(order.Condition, conds{c}));
        
        stim = nirs.design.StimulusEvents;
        stim.onset = t0 + order.Onset(ind);
        stim.dur = order.Duration(ind);
        stim.amp = order.Weight(ind);
        stim.name = conds{c};
        
        regressor_no_interest = ~order.Interest(ind);
        if range(regressor_no_interest)
            error('All trials of the same condition must be marked as "of interest" or "not of interest"')
        end
        stim.regressor_no_interest = regressor_no_interest(1);
        
        new_cond(conds{c}) = stim;
    end
    raw.stimulus = new_cond;
    
    
    fprintf('%s\tCreating comparison figure...\n', print_prefix);
    fig = figure('Position', get(0,'ScreenSize'));
    set(gcf,'color','k');
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');
    labels = cell(0);
    plots = [];
    colours = [0.5 0.5 0.5; jet(old_cond.count + new_cond.count)];
    hold on
    
    id = 1;
    labels{id} = 'Cleared';
    plots(id) = plot(-1,-1,'-','Color',colours(id,:),'LineWidth',10);
    rectangle('Position',[0 0 raw.time(1) 1], 'FaceColor', colours(id,:));
    rectangle('Position',[raw.time(end) 0 (duration - raw.time(end)) 1], 'FaceColor', colours(id,:));
    
    for i = 1:2
        if i==1
            stim = old_cond;
            t = 'Prior';
        else
            stim = new_cond;
            t = 'New';
        end
        
        for c = 1:stim.count
            id = id + 1;
            labels{id} = [t ': ' strrep(stim.keys{c},'_',' ')];
            
            for e = 1:length(stim.values{c}.onset)
                time_start = stim.values{c}.onset(e);
                dur = max(0.5, stim.values{c}.dur(e));
                
                rectangle('Position',[time_start (2-i) dur 1], 'FaceColor', colours(id,:));
                plots(id) = plot(-1,-1,'-','Color',colours(id,:),'LineWidth',10);
            end
        end
    end
    hold off
    grid minor
    axis([0 duration 0 2])
    legend(plots, labels, 'TextColor', 'w', 'Location', 'EastOutside')
    title(sprintf('Comparing Prior Conditions/Triggers to Imported Conditions\n%s', strrep(bids_info.datasets.full_name, '_', ' ')), 'Color', 'w');
    xlabel 'Time (sec)';
    set(gca,'ytick',[0.5 1.5],'yticklabels', {'New' 'Prior'});
        
    filepath = fNIRSTools.bids.io.getFilepath('import_cond_comparison_fig', bids_info, false);
    fprintf('%s\t\tWriting: %s\n', print_prefix, filepath);
    img = getframe(gcf);
    imwrite(img.cdata,filepath);
    close(fig);
    
end

%% Save RAW

fprintf('%sWriting RAW: %s\n', print_prefix, filepath_raw);
data = raw;
save(filepath_raw, 'data')

%% Save SNIRF

fprintf('%sWriting SNIRF: %s\n', print_prefix, filepath_snirf);
nirs.io.saveSNIRF(raw, filepath_snirf);
