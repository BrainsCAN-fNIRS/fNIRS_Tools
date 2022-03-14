classdef QTExcludeChannels < nirs.modules.AbstractModule
    properties
        threshold_sci = 0.3;
        threshold_ratio = 2/3; %percent of time bins above threshold to keep channel
        fill_value = nan;
        window_sec = 5;
        window_overlap = 0;
        cardiac_freq = [0.5 2.5];
    end
    
    methods
        function obj = QTExcludeChannels( prevJob )
           obj.name = 'Exclude channels with poor SCI. Requires QT-NIRS.';
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
					if ~isnumeric(data(i).probe.types)
						if ~any(strcmp(data(i).probe.link.Properties.VariableNames, 'RatioGoodSCI'))
							error('Cannot be called after MBLL unless QTAddChannelMeasures has already been applied')
						else
							%use values from QTAddChannelMeasures if called after MBLL
							%NOTE: only fill_value and threshold_ratio are used here, the other params must have been set during QTAddChannelMeasures
							ind_to_exclude = data(i).probe.link.RatioGoodSCI < obj.threshold_ratio;
							channels_to_exclude = ind_to_exclude(strcmp(data(i).probe.link.type, data(i).probe.types{1}));
						end
					else
						%standard method...
					
						%job
						job = nirs.modules.QT;
						job.windowSec = obj.window_sec;
						job.windowOverlap = obj.window_overlap;
						job.fCut = obj.cardiac_freq;
						
						%calculte sci with qt-nirs
						ind_nan = isnan(data(i).data);
						data(i).data(ind_nan) = 1;
						qt = job.run(data(i));
						data(i).data(ind_nan) = nan;
						sci = qt.qMats.sci_array;

						%set invalid to nan
						sci(sci==0) = nan;

						%find bins above threshold
						sci_at_thresh = sci >= obj.threshold_sci;

						%calculate percent of bins above thresh for each channel
						sci_at_thresh_pct = mean(sci_at_thresh,2);

						%identify channels to exclude
						channels_to_exclude = sci_at_thresh_pct < obj.threshold_ratio;

						%convert channels to indices
						sd_pairs = qt.qMats.good_combo_link(channels_to_exclude,1:2);
						ind_to_exclude = [];
						for j = 1:size(sd_pairs,1)
							ind = find((data(i).probe.link.source == sd_pairs(j,1)) & (data(i).probe.link.detector == sd_pairs(j,2)));
							ind_to_exclude = [ind_to_exclude; ind];
						end
					
					end

                    %apply exclusions
                    data(i).data(:,ind_to_exclude) = obj.fill_value;
                    data(i).probe.link.PoorSCI(:) = false;
                    data(i).probe.link.PoorSCI(ind_to_exclude) = true;

                    %display
                    fprintf('%d channels were excluded\n', sum(channels_to_exclude));
                end
            end
        end
        
    end
end