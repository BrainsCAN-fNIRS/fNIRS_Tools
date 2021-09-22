%Requires MATLAB Signal Processing Toolbox
classdef bandpassFilter < nirs.modules.AbstractModule
    properties
        passbandFrequencies = [0.01 0.2];
    end
    
    methods
        function obj = bandpassFilter( prevJob )
           obj.name = 'Bandpass Filter';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if length(obj.passbandFrequencies)~=2 || ~isnumeric(obj.passbandFrequencies) || any(isnan(obj.passbandFrequencies)) || any(obj.passbandFrequencies <= 0)
                error('Invalid passband')
            else
                % for each file
                for i = 1:numel(data)
                    invalid_data = isnan(data(i).data) | (data(i).data == 0);
                    empty_channel = ~any(~invalid_data,1); 
                    data(i).data(:,empty_channel) = 0;
                    data(i).data = bandpass(data(i).data, obj.passbandFrequencies, data(i).Fs);
                    data(i).data(:,empty_channel) = nan;
                end
            end
        end
        
    end
end