classdef SNRAveragePerChannel < nirs.modules.AbstractModule
%'channelwise' averaging of the SNR 
%as SNR is calculated on the raw data (before OD and MBLL) this data is
%technically dimensionless
%this script can also only be run after SNRCalculatePerSignal

    properties
    end
    
    methods
        function obj = SNRAveragePerChannel( prevJob )
           obj.name = 'average SNR for wavelengths per SD pair following SNRCalculatePerSignal';
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
          
                for i = 1:numel(data)
                    
                    %step 1 check if SNR exist within the data.probe.link
                    %file
                    SNR_col = strcmp('SNR',data(i).probe.link.Properties.VariableNames);
                    if ~any(SNR_col)
                        error('The data.probe.link file does not contain a column named "SNR"');
                    else     
                        
                        %step 2 Find unique source detector pairings   
                        [~, ~, unique_pairs_num] =  unique(data(i).probe.link(:,1:2), 'rows');
                        pair_indices = accumarray(unique_pairs_num, find(unique_pairs_num), [], @(rows){rows});

                        %step 3 calculate the actual averages for SNR
                        SNR_averages = nan(height(data(i).probe.link),1); %predefine an array for storing the averages values
                        for j = 1:numel(pair_indices)
                            current_locs = cell2mat(pair_indices(j)); 
                            SNR_averages(current_locs) = nanmean(data(i).probe.link{current_locs,SNR_col}); 
                        end
                        
                        %step 4 replace the SNR values with the averaged
                        %SNR values
                        data(i).probe.link.Properties.VariableNames(SNR_col) = {'SNR_SD_averaged'};
                        data(i).probe.link(:,SNR_col) = array2table(SNR_averages);
                    end   
                end   
        end
    end            
end