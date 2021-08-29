classdef QTAddChannelMeasures < nirs.modules.AbstractModule
    properties
        threshold_sci = 0.3;
        threshold_psp = 0.03;
        windowSec = 5;
        windowOverlap = 0;
    end
    
    methods
        function obj = QTAddChannelMeasures( prevJob )
           obj.name = 'Adds the channel-wise ratios of time bins with above-threshold sci, psp, and sci&psp to the probe.link table. Requires QT-NIRS.';
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
                    
                    %initialize
                    data(i).probe.link.RatioGoodSCI(:) = nan;
                    data(i).probe.link.RatioGoodPSP(:) = nan;
                    data(i).probe.link.RatioGoodSCIandPSP(:) = nan;
                    
                    %calc and store in probe.link
                    for j = 1:height(data(i).probe.link)
                        ind = find((qt.qMats.good_combo_link(:,1) == data(i).probe.link.source(j)) & (qt.qMats.good_combo_link(:,2) == data(i).probe.link.detector(j)));
                        data(i).probe.link.RatioGoodSCI(j) = nanmean(sci_at_thresh(ind,:));
                        data(i).probe.link.RatioGoodPSP(j) = nanmean(psp_at_thresh(ind,:));
                        data(i).probe.link.RatioGoodSCIandPSP(j) = nanmean(sci_at_thresh(ind,:) & psp_at_thresh(ind,:));
                    end

                end
            end
        end
        
    end
end