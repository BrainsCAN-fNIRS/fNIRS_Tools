classdef renameDECONv2Spikes < nirs.modules.AbstractModule
    properties
        times = [];
    end
    
    methods
        function obj = renameDECONv2Spikes( prevJob )
           obj.name = 'Renames the spike conditions following DECONv2 to match their actual times instead of their indicies.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                %make a reference copy
                ref = data(i);

                %default to unknown
                data(i).variables.cond(:) = {'unknown'};

                %rename each condition
                for cond = 1:length(ref.conditions)
                    %old name...
                    name_prior = ref.conditions{cond};

                    %get spike index
                    parts = strsplit(name_prior, ':');
                    spike_index = str2num(parts{2});

                    %create new name with spike timing
                    name_new = sprintf('%s:%02d', parts{1}, obj.times(spike_index));

                    %replace
                    ind = strcmp(ref.variables.cond, name_prior);
                    data(i).variables.cond(ind) = {name_new};
                end
            end
        end
        
    end
end