classdef calculateSNR < nirs.modules.AbstractModule
%THIS HAS TO BE RUN ON THE RAW DATA (BEFORE RESAMPLING, OPTICAL DENSITY AND MBLL)

    properties
    end
    
    methods
        function obj = calculateSNR( prevJob )
           obj.name = 'calculate SNR';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
             % for each file
                for i = 1:numel(data)                    
                    SNR = nanmean(data(i).data,1)./nanstd(data(i).data,[],1);
                    data(i).probe.link.SNR = SNR';   
                end
        end
        
    end
end