%Requires MATLAB Signal Processing Toolbox
classdef highpassFilter < nirs.modules.AbstractModule
    properties
        passbandFrequency = 0.01;
    end
    
    methods
        function obj = highpassFilter( prevJob )
           obj.name = 'Highpass Filter';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            if length(obj.passbandFrequency)~=1 || ~isnumeric(obj.passbandFrequency) || isnan(obj.passbandFrequency) || (obj.passbandFrequency <= 0)
                error('Invalid passband')
            else
                % for each file
                for i = 1:numel(data)
                    is_nan = isnan(data(i).data);
                    data(i).data(is_nan) = 0;
                    
                    data(i).data = highpass(data(i).data, obj.passbandFrequency, data(i).Fs);
                    
                    data(i).data(is_nan) = nan;
                end
            end
        end
        
    end
end