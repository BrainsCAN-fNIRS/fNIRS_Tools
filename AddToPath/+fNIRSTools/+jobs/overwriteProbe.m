classdef overwriteProbe < nirs.modules.AbstractModule
    properties
        probe = [];
    end
    
    methods
        function obj = overwriteProbe( prevJob )
           obj.name = 'Overwrites the data.probe with the provided probe. No merging or checks are performed.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            % confirm that probe has been set
            if ~isa(obj.probe, 'nirs.core.Probe')
                error('"probe" must be set to a valid "nirs.core.Probe" or "nirs.core.Probe1020"')
            end

            for i = 1:numel(data)
                % replace probe object
                data(i).probe = obj.probe;
            end
        end
    end
end