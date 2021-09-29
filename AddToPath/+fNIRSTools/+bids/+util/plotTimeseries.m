% fNIRSTools_bids_util_plotTimeseries(bids_info, input_suffixes, output_suffix, labels, normalize, freq_range, average_freq)
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
%
%   labels          {char}          default={}      Labels for each input data set (defaults to input suffix)
%
%   normalize       [logical]       default=false   Flag to normalize each input set by its variance
%
%   freq_range      {[# #]}         default=[]      Frequency range to display. Can be set for each series with a cell array. (defaults to full)
%
%   average_freq    logical         default=false   If true, frequency plots will display the average across channels instead.
%
function fNIRSTools_bids_util_plotTimeseries(bids_info, input_suffixes, output_suffix, labels, normalize, freq_range, average_freq)

%% Inputs

if ~iscell(input_suffixes)
    input_suffixes = {input_suffixes};
end
number_input_types = length(input_suffixes);

%% Defaults

if ~exist('output_suffix', 'var') || isempty(output_suffix)
    output_suffix = nan;
end
if isnumeric(output_suffix) && numel(output_suffix)==1 && isnan(output_suffix)
    output_suffix = '';
end

if ~exist('labels', 'var') || isempty(labels)
    labels = strrep(input_suffixes,'_','\_');
end

if ~exist('normalize', 'var') || isempty(normalize)
    normalize = false;
end
if length(normalize)==1
    normalize = repmat(normalize, [1 number_input_types]);
end

if ~exist('freq_range', 'var')
    freq_range = [];
end
if ~iscell(freq_range)
    freq_range = repmat({freq_range}, [1 number_input_types]);
end

if ~exist('average_freq', 'var') || isempty(average_freq)
    average_freq = false;
end

%% Output Folder

directory = [bids_info.root_directory 'derivatives' filesep 'figures' filesep 'plotTimeseries' filesep];
if ~exist(directory, 'dir')
    mkdir(directory);
end

%% Run Each
fig = figure('Position', get(0,'ScreenSize'));
for ds = 1:bids_info.number_datasets
    %load
    data = cellfun(@(set) fNIRSTools.bids.io.readFile(bids_info, set, ds), input_suffixes);
    
    %count data types in each file
    data_types_count = arrayfun(@(d) length(d.probe.types), data);
    data_types_max = max(data_types_count);
    number_rows = (data_types_max * 2) + 2;
    
    %
    clf
    for input_type = 1:number_input_types
        for data_type = 1:data_types_count(input_type)
            if iscell(data(input_type).probe.types)
                data_type_name = data(input_type).probe.types{data_type};
                signal_ind = strcmp(data(input_type).probe.link.type, data_type_name);
            else
                data_type_name = [num2str(data(input_type).probe.types(data_type)) 'nm'];
                signal_ind = data(input_type).probe.link.type == data(input_type).probe.types(data_type);
            end
            
            ind = (input_type) + ((data_type-1)*number_input_types*2);
            
            %prep signal
            signals = data(input_type).data(:,signal_ind);
            signals = signals(:,range(signals)>0);
            
            %prep timeseries
            timeseries = signals;
            if normalize(input_type)
                timeseries = (timeseries - nanmean(timeseries)) ./ nanstd(timeseries);
            end
            
            %draw timeseries
            subplot(number_rows, number_input_types, ind)
            plot(data(input_type).time,timeseries);
            t = data_type_name;
            if data_type==1
                t = sprintf('%s\n%s', labels{input_type}, t);
            end
            if normalize(input_type)
                t = sprintf('%s\nNormalized for Visualization', t);
            end
            title(t)
            xlabel('Time (sec)');
            ylabel('Intensity');
            v = axis;
            axis([min(data(input_type).time) max(data(input_type).time) v(3:4)])
            
            %calc frequency
            y = fft(signals);  
            fs = data(input_type).Fs;
            f = (0:length(y)-1)*fs/length(y);   
            power = abs(y);
            if average_freq
                f = f(1,:);
                power = nanmean(power,2);
            end
            
            %draw frequency
            ind = ind + number_input_types;
            subplot(number_rows, number_input_types, ind)
            plot(f,power)
            xlabel('Frequency (Hz)');
            ylabel('Power');
            v = axis;
            if isempty(freq_range{input_type})
                freq_range_use = [f(1) f(end)];
            else
                freq_range_use = freq_range{input_type};
            end
            r = range(freq_range_use)*.05;
            axis_max = nanmax(nanmax(power(f>(freq_range_use(1)+r) & f<(freq_range_use(end)-r) , :)));
            axis([freq_range_use 0 axis_max])
        end
        
        %correlation figure
        [~,order] = sort(data(input_type).probe.link.type);
        
        types = data(input_type).probe.link.type(order);
        if isnumeric(types)
            types = arrayfun(@num2str, types, 'UniformOutput', false);
        end
        unique_types = unique(types);
        label_inds = cellfun(@(t) find(strcmp(types,t),1,'first'), unique_types);
        
        corrs = corr(data(input_type).data(:,order));
        ind = (input_type) + (data_types_count(input_type)*number_input_types*2);
        ind = [ind (ind+number_input_types)];
        subplot(number_rows, number_input_types, ind)
        imagesc(corrs)
        cb = colorbar;
%         ylabel(cb, 'Correlation')
        axis square
        title('Correlations','FontSize',10)
%         axis off
        set(gca,'ytick',label_inds,'yticklabel',unique_types,'xtick',[])
        
        cm = [1 1 1; parula];
        colormap(cm);
        caxis([-1.05 +1]);
    end
    
    %main title
    t = strrep(bids_info.datasets(ds).full_name,'_','\_');
%     if ~isempty(freq_range)
%         t = sprintf('%s (%g to %g Hz)', t, freq_range_use);
%     end
    sgtitle(t);
    
    %save
    saveas(fig, [directory bids_info.datasets(ds).full_name output_suffix '.png']);
end
close(fig);


