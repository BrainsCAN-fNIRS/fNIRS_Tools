classdef QTAllWavelength < nirs.modules.AbstractModule
    properties
        fCut = [0.5 2.5];
        windowSec = 5;
        windowOverlap = 0;
    end
    
    methods
        function obj = QTAllWavelength( prevJob )
            if nargin > 0; obj.prevJob = prevJob; end
            obj.name = 'Run QT for each pair of wavelength and store the average SCI and PSP matrices';
        end
        
        function S = runThis( obj, data )
            job_qt = nirs.modules.QT;
            job_qt.fCut = obj.fCut;
            job_qt.windowSec = obj.windowSec;
            job_qt.windowOverlap = obj.windowOverlap;
            
            job_wl = fNIRSTools.jobs.KeepTypes;
            
            S = repmat(nirs.core.QTNirs, [length(data) 0]);
            
            for i = 1:numel(data)
                if(isa(data(i),'nirs.core.Data')) 
                    %get type pairs
                    wavelength_pairs = nchoosek(data(i).probe.types, 2);
                    number_pairs = size(wavelength_pairs, 1);
                    results = repmat(nirs.core.QTNirs, [1 1 number_pairs]);
                    
                    %run each pair
                    for p = 1:number_pairs
                        job_wl.types = arrayfun(@num2str, wavelength_pairs(p,:), 'UniformOutput', false);
                        d = job_wl.run(data(i));
                        results(p) = job_qt.run(d);
                    end
                    
                    %average across the results
                    S(i).qMats.sci_array = mean(cell2mat(arrayfun(@(x) x.qMats.sci_array, results, 'UniformOutput', false)), 3);
                    S(i).qMats.power_array = mean(cell2mat(arrayfun(@(x) x.qMats.power_array, results, 'UniformOutput', false)), 3);
                else
                    error('unsupported type');
                end
                
            end
        end
    end
end
