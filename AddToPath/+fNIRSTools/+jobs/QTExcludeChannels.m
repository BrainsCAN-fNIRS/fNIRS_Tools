classdef QTExcludeChannels < nirs.modules.AbstractModule
    properties
        threshold_sci = 0.3;
        threshold_ratio = 2/3; %percent of time bins above threshold to keep channel
        fill_value = nan;
        windowSec = 5;
        windowOverlap = 0;
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
                    %job
                    job = nirs.modules.QT;
                    job.windowSec = obj.windowSec;
                    job.windowOverlap = obj.windowOverlap;
                    job.sciThreshold = obj.threshold_sci;
                    job.pspThreshold = obj.threshold_psp;
                    
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