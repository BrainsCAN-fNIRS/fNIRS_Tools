classdef SNRFlagNoisyChannelsPct < nirs.modules.AbstractModule
%Flagging noisy channels based on an SNR threshold
%NOTE THAT THIS SCRIPT IS MADE TO ONLY WORK ON AVERAGED SNR VALUES
% it could technically work on seperate values as well (e.g. on wavelengths not hbO)
%but considering that fNIRS is always looked at on the hbo hbr level, there
%does not seem to be a use for also doing it on WLs

    properties
        SNRthresholdPct = 0.25; %SNR threshold as percent of the average
    end
    
    methods
        function obj = SNRFlagNoisyChannelsPct( prevJob )
           obj.name = 'flag noisy channels following on SNRAveragePerChannel';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            
            for i = 1:numel(data)
                %step 1 checking if correct things are here
                SNR_col = strcmp('SNR_SD_averaged',data(i).probe.link.Properties.VariableNames);
                if length(obj.SNRthresholdPct)~=1 || ~isnumeric(obj.SNRthresholdPct) || isnan(obj.SNRthresholdPct) || (obj.SNRthresholdPct <= 0)
                    error('Invalid threshold for calculating SNR')
                elseif ~any(SNR_col)
                    error('The data.probe.link file does not contain a column named "SNR_SD_averaged"');
                else    
                end
                
				%calc threshold
				snr_thresh = nanmean(data(i).probe.link{:,SNR_col}) * obj.SNRthresholdPct;
				data(i).demographics('snr_thresh') = snr_thresh;
				
                %here we flag the data which is added as a column
                
               data(i).probe.link.('noisy_channel') =  data(i).probe.link{:,SNR_col} < snr_thresh;
                
            end
            
            
        end
    end
end
            
               
      