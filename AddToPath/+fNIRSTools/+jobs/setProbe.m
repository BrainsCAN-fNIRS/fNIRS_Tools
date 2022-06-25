classdef setProbe < nirs.modules.AbstractModule
    properties
        probe = nirs.core.Probe;
        position_match_threshold = 0.01;
    end
    
    methods
        function obj = setProbe( prevJob )
           obj.name = 'Set a new probe. Optode positions must match within threshold. If no match is found, channel is set NaN. Absent channels are discarded. Based on 2D srcPos/detPos.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                %check type compatability
                if isnumeric(data(i).probe.types) ~= isnumeric(obj.probe.types)
                    error('Signal type mismatch')
                end

                %match sources by 2D position
                number_sources = size(obj.probe.srcPos, 1);
                source_lookup = nan(1, number_sources);
                for s = 1:number_sources
                    dists = sqrt(sum((data(i).probe.srcPos - obj.probe.srcPos(s,:)) .^ 2, 2));
                    ind_in_data = find(dists <= obj.position_match_threshold);
                    if length(ind_in_data) == 1
                        source_lookup(s) = ind_in_data;
                    end
                end
                
                %match detectors by 2D position
                number_detectors = size(obj.probe.detPos, 1);
                detector_lookup = nan(1, number_detectors);
                for s = 1:number_detectors
                    dists = sqrt(sum((data(i).probe.detPos - obj.probe.detPos(s,:)) .^ 2, 2));
                    ind_in_data = find(dists <= obj.position_match_threshold);
                    if length(ind_in_data) == 1
                        detector_lookup(s) = ind_in_data;
                    end
                end

                %initialize
                number_signals = height(obj.probe.link);
                new_data = nan(size(data(i).data,1) , number_signals);

                %add each signal
                signals_copied = 0;
                for s = 1:number_signals
                    %find SD matches
                    match_sd = (data(i).probe.link.source == source_lookup(obj.probe.link.source(s))) & (data(i).probe.link.detector == detector_lookup(obj.probe.link.detector(s)));

                    %find type matches
                    if isnumeric(obj.probe.types)
                        match_type = (data(i).probe.link.type == obj.probe.link.type(s));
                    else
                        match_type = strcmp(data(i).probe.link.type, obj.probe.link.type{s});
                    end

                    %find exact match
                    ind = find(match_sd & match_type);
                    if length(ind) ~= 1
                        continue
                    end

                    %copy signal
                    new_data(:,s) = data(i).data(:,ind);

                    %count success
                    signals_copied = signals_copied + 1;
                end

                %print counts
                fprintf('Found %d of %d target signals (%d available).\n', signals_copied, number_signals, height(data(i).probe.link));

                %apply changes
                data(i).data = new_data;
                data(i).probe = obj.probe;
            end
        end
    end
end