classdef noisy2nan < nirs.modules.AbstractModule
%Noisy channels can be made NaN after applying optical density and MBLL.
% So this script follows after flagNoisyChannels before preprocessing,
% followed by preproccessing and then applying noisy2nan on MBLL data

    properties
    end
    
    methods
        function obj = noisy2nan( prevJob )
           obj.name = 'noisy channels to nan values';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            
            for i = 1:numel(data)
                %step 1 checking if correct things are here
                flag_col = strcmp('noisy_channel',data(i).probe.link.Properties.VariableNames);
                if ~any(flag_col)
                    error('The data.probe.link file does not contain a column named "noisy_channel". Note there should be no space between words');    
                end
                
               flagged_chans = data(i).probe.link{:,flag_col} == 1;
               data(i).data(:,flagged_chans) = nan;
                
             
                
            end
            
            
        end
    end
end
            
               
      