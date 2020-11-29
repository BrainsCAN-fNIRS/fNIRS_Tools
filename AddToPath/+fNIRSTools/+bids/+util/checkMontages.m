%[all_identical] = fNIRSTools_bids_util_checkMontages(bids_info, do_all_comparisons, data)
%
% Reads all snirf files (or *_RAW.mat if available) and check if they have
% the same montage.
% 
% Outputs:
%   all_identical           logical     indicates whether all datasets had the same montage
%
% Inputs:
%   do_all_comparisons      logical     default=false       when true, all pairs of datasets are compared
%   
%   data                    [struct]    no default          can optionally pass data to avoid reloading
%
function [all_identical] = fNIRSTools_bids_util_checkMontages(bids_info, do_all_comparisons, data)

%% Inputs

if ~exist('complete', 'var')
    do_all_comparisons = false;
end

%% Read Montages

%read data if not provided
if ~exist('data', 'var')
    %if all runs have raw or HB mat, it's much faster to get montages from there
    [~,exists_raw] = fNIRSTools.bids.io.getFilepath('RAW', bids_info, true);
    if ~any(~exists_raw)
        data = fNIRSTools.bids.io.readFile(bids_info, 'RAW');
    else
        warning('Did not locate full set of raw mat files. Reading directly from SNIRF instead, which is slower.')
        data = fNIRSTools.bids.io.readFile(bids_info, 'SNIRF');
    end
end

montages = arrayfun(@(f) f.probe, data);
number_montages = length(montages);
if number_montages < 2
    error('Found less than 2 montages')
end

%% Compare

if ~do_all_comparisons
    fprintf('Comparing montages (reduced comparison method)...\n');
    
    montage_ref = montages(1);
    same = [1; arrayfun(@(m) compareMontage(montage_ref, m), montages(2:end))];
    
    montage_matches_first = [{bids_info.datasets.full_name}' num2cell(same)];
    disp 'Results of comparison to first montage (1=same, 0=diff):'
    disp(montage_matches_first)
else
    fprintf('Comparing montages (complete comparison method)...\n');
    
    %make all comparisons
    same = nan(number_montages,number_montages);
    for m1 = 1:number_montages
        for m2 = m1:number_montages
            same(m1,m2) = compareMontage(montages(m1),montages(m2));
            same(m2,m1) = same(m1,m2);
        end
    end
    
    %figure
    fig = figure('Position', get(0,'ScreenSize'));
    set(gcf,'color','k');
    set(gca, 'Color', 'k', 'GridColor', 'w', 'MinorGridColor', 'w', 'XColor', 'w', 'YColor', 'w');
    imagesc(same)
    axis square
    cb = colorbar;
    set(cb, 'ytick', [0.05 0.95], 'yticklabel', {'Different' 'Same'});
    colormap([0 0 0.5; 0 0.5 0]);
    caxis([0 1]);
    set(gca, 'xtick', 0.5:1:number_montages, 'xticklabel', 1:number_montages, 'ytick', 1:number_montages, 'yticklabel', cellfun(@(x) strrep(x, '_', ''), {bids_info.datasets.full_name}, 'UniformOutput', false))
    grid on
    title('Montage Comparison', 'Color', 'white')
    
    filepath = fNIRSTools.bids.io.getFilepath('MONTAGE_COMPARISON_FIG', bids_info, false, true);
    fprintf('Writing: %s\n', filepath);
    img = getframe(gcf);
    imwrite(img.cdata,filepath);
    close(fig);
end

all_identical = ~any(~same(:));
if ~all_identical
    warning('Montages are not all identical')
end



function [same] = compareMontage(montage_source, montage_target)

%default
same = true;

%link table
if any(size(montage_source.link) ~= size(montage_target.link))
    same = false;
    return
else
    %check S/D index
    check = (montage_source.link.detector ~= montage_target.link.detector) | ...
            (montage_source.link.source ~= montage_target.link.source);
    
    %check data type
    if isnumeric(montage_source.link.type(1))
        check = check | (montage_source.link.type ~= montage_target.link.type);
    else
        check = check | ~strcmp(montage_source.link.type, montage_target.link.type);
    end
        
    if any(check(:))
        same = false;
        return
    end
end

%source positions
if any(size(montage_source.srcPos) ~= size(montage_target.srcPos))
    same = false;
    return
else
    check = montage_source.srcPos ~= montage_target.srcPos;
    if any(check(:))
        same = false;
        return
    end
end

%detector positions
if any(size(montage_source.detPos) ~= size(montage_target.detPos))
    same = false;
    return
else
    check = montage_source.detPos ~= montage_target.detPos;
    if any(check(:))
        same = false;
        return
    end
end

