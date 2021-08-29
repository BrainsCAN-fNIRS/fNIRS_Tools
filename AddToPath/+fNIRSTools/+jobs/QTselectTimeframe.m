classdef QTSelectTimeframe < nirs.modules.AbstractModule
    properties
        threshold_sci = 0.3;
        threshold_psp = 0.03;
        duration_sec = 180;
        windowSec = 5;
        windowOverlap = 0;
    end
    
    methods
        function obj = QTSelectTimeframe( prevJob )
           obj.name = 'Restrict samples to the cleanest continuous subset based on SCI and PSP. Requires QT-NIRS.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if ~exist('nirs.modules.QT')
                error('Could not find QT module.');
            end
            
            for i = 1:numel(data)
                if ~any(strcmp(fields(data(i)),'data'))
                    error('data structure does not contain "data" field')
                else
                    %job
                    job = nirs.modules.QT;
                    job.windowSec = obj.windowSec;
                    job.windowOverlap = obj.windowOverlap;
                    
                    %calculte sci and psp with qt-nirs
                    ind_nan = isnan(data(i).data);
                    data(i).data(ind_nan) = 1;
                    qt = job.run(data(i));
                    data(i).data(ind_nan) = nan;
                    sci = qt.qMats.sci_array;
                    psp = qt.qMats.power_array;

                    %set invalid to nan
                    sci(sci==0) = nan;
                    psp(psp==0) = nan;

                    %find bins above threshold
                    sci_at_thresh = sci >= obj.threshold_sci;
                    psp_at_thresh = sci >= obj.threshold_psp;

                    %calculate quality value at each bin
                    bin_value = sum(sci_at_thresh + psp_at_thresh, 1);

                    %how many bins to select
                    bin_duration = qt.qMats.sampPerWindow / qt.qMats.fs;
                    bins_to_select = min(ceil(obj.duration_sec / bin_duration), qt.qMats.n_windows);

                    %evaluate all possible timeframes
                    number_of_selection = (qt.qMats.n_windows - bins_to_select + 1);
                    selection_value = nan(1, number_of_selection);
                    for bin_start = 1:number_of_selection
                        bins_selected = bin_start:(bin_start+bins_to_select - 1);
                        selection_value(bin_start) = sum(bin_value(bins_selected));
                    end

                    %select best timeframe
                    [~,best_bin_start] = max(selection_value);
                    time_start = data(i).time(1) + (best_bin_start - 1) * bin_duration;
                    time_end = time_start + obj.duration_sec;

                    %check if selection is possible
                    if time_end > data(i).time(end)
                        error('Could not select full duration (%g seconds)', obj.duration_sec)
                    end

                    %restrict samples
                    samples_to_use = (data(i).time >= time_start) & (data(i).time <= time_end);
                    data(i).data = data(i).data(samples_to_use,:);
                    data(i).time = data(i).time(samples_to_use);

                    %display
                    fprintf('Selected %gsec to %gsec\n', time_start, time_end);
                end
            end
        end
        
    end
end