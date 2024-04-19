classdef renameDECONv3Spikes < nirs.modules.AbstractModule
    properties
    end
    
    methods
        function obj = renameDECONv3Spikes( prevJob )
           obj.name = 'Renames the spike conditions following DECONv3 to match their actual times instead of their indicies.';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)
                %make a reference copy
                ref = data(i);

                %get condition spike indices
                re = regexp(ref.conditions, '(?<cond>.+):(?<spike>.+)', 'names');
                pred_cond = cellfun(@(c) c.cond, re, UniformOutput=false);
                pred_spike = cellfun(@(c) str2num(c.spike), re);

                %check that all conditions had DECONv3 basis
                conds = unique(pred_cond);
                for c = 1:length(conds)
                    %contains basis
                    if ~ref.basis.base.iskey(conds{c})
                        error('Decon did not contain basis for: [%s]', conds{c})
                    end

                    %basis is DECONv3
                    if ~isa(ref.basis.base(conds{c}),'DECONv3')
                        error('The basis for [%s] was not DECONv3', conds{c})
                    end
                end

                %default to unknown
                data(i).variables.cond(:) = {'unknown'};

                %rename each condition
                for cond = 1:length(ref.conditions)
                    %get the basis for the sample pre/post
                    basis = ref.basis.base(pred_cond{cond});

                    %calc samples
                    samples = -basis.samples_pre : +basis.samples_post;
                    samples_time = samples / ref.basis.Fs;

                    %get this time
                    time = samples_time(pred_spike(cond));

                    %names
                    name_prior = ref.conditions{cond};
                    name_new = sprintf('%s:%08.4f', pred_cond{cond}, time);

                    %replace
                    ind = strcmp(ref.variables.cond, name_prior);
                    data(i).variables.cond(ind) = {name_new};
                end

            end
        end
        
    end
end