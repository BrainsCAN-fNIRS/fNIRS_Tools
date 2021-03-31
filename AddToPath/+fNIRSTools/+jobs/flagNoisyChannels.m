classdef flagNoisyChannels < nirs.modules.AbstractModule
%Flagging noisy channels based on an SNR threshold
%NOTE THAT THIS SCRIPT IS MADE TO ONLY WORK ON AVERAGED SNR VALUES
% it could technically work on seperate values as well (e.g. on wavelengths not hbO)
%but considering that fNIRS is always looked at on the hbo hbr level, there
%does not seem to be a use for also doing it on WLs

    properties
        SNRthreshold = 6.67;
%https://support.nirx.de/archives/knowledge/enprunechannels-function-thresholds
% snr_threshold_strict = 13.33; % This is the same as red in nirstar (Coefficient of variation = 7.5%)
% snr_threshold_loose = 6.67; %this is CV of 15%. Nirstar doesn't give a reason for this, but I assume they consider it lost
% snr_threshold_homer = 2; %this vale is used in Homer3
    end
    
    methods
        function obj = flagNoisyChannels( prevJob )
           obj.name = 'flag noisy channels';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            
            for i = 1:numel(data)
                %step 1 checking if correct things are here
                SNR_col = strcmp('SNR_SD_averaged',data(i).probe.link.Properties.VariableNames);
                if length(obj.SNRthreshold)~=1 || ~isnumeric(obj.SNRthreshold) || isnan(obj.SNRthreshold) || (obj.SNRthreshold <= 0)
                    error('Invalid threshold for calculating SNR')
                elseif ~any(SNR_col)
                    error('The data.probe.link file does not contain a column named "SNR_SD_averaged"');
                else    
                end
                
                %here we flag the data which is added as a column
                
               data(i).probe.link.('noisy_channel') =  data(i).probe.link{:,SNR_col} < obj.SNRthreshold;
                
            end
            
            
        end
    end
end
            
               
      