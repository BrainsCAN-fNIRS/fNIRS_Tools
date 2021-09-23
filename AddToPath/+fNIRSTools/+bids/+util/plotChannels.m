% plotChannels(bids_info, input_suffixes, varargin )
%
% Creates one image file per channel containing the timecourse from each
% stage specified in input_suffixes. Can be used to compare across stages
% and/or to view channels individually (useful for large montages).
%
% INPUTS:
%   bids_info               struct          no default      bids_info structure specifying datasets to use
%                                                               Modes:
%                                                                   1. Single dataset to plot it directly
%                                                                   2. Multiple datasets from one participant to plot their mean and 95%CI
%                                                                   3. Multiple datasets from multiple participants to plot mean and 95%CI of participant means
%                                                                       (weight by participant, not by dataset)
%
%   input_suffixes          {char}          no default      Suffixes indicating stages to plot
%
%   output_suffix           char/nan        default=[]      Suffix to add to output (no suffix if nan)
%
%   draw_events             char            default=generic Draws events behind eachtimecourse. off=disabled, generic=indicate trials, condition=indicate trials with colour-coded conditions 
%
%   sd_pairs                Nx2             default=[]      If not empty, only the specified source-detector pairs will be processed
%
%   condition_colours       Nx3             default=[]      Colours to use if draw_events=2. In order of data.stimulus.
%
%   show_location           logical         default=true    Indicate the channel location in a montage view beside the plots
%
%   dateset_labels          {char}          default={}      Labels for each stage, same order as input_suffixes (defaults to the suffixes)
%
%   dateset_normalize       [logical]       default=false   Flag to normalize signals in each stage, same order as input_suffixes
%
%   dateset_type_colours	{[Nx3]}         default={}      Line colours for each signal type at each stage (in order of probe.types), same order as input_suffixes
%
%   dateset_yaxis_limits	{[1x2]}         default={}      Y-axis limits to use at each stage, same order as input_suffixes
%
function plotChannels(bids_info, input_suffixes, namedargs)
arguments
    %required fields
    bids_info struct
    input_suffixes {fNIRSTools.internal.verify.CellsAreChar}
    
    %name-value pairs...
    
    %general parameters
    namedargs.output_suffix char = []
    namedargs.draw_events char {mustBeMember(namedargs.draw_events, {'off' 'generic' 'condition'})} = 'generic'
    namedargs.sd_pairs {fNIRSTools.internal.verify.IntegersOnly(namedargs.sd_pairs)} = []
    namedargs.condition_colours (:,3) {mustBeInRange(namedargs.condition_colours,0,1)} = []
    namedargs.show_location logical = true
    
    %per-set parameters
    namedargs.dateset_labels {fNIRSTools.internal.verify.CellsAreChar , fNIRSTools.internal.verify.LengthMatch(namedargs.dateset_labels, input_suffixes)} = strrep(input_suffixes, '_', '/_')
    namedargs.dateset_normalize {mustBeA(namedargs.dateset_normalize,'logical') , fNIRSTools.internal.verify.LengthMatch(namedargs.dateset_normalize, input_suffixes, 1)} = false(1,length(input_suffixes));
    namedargs.dateset_type_colours {fNIRSTools.internal.verify.LengthMatch(namedargs.dateset_type_colours, input_suffixes) , fNIRSTools.internal.verify.SizeInCells(namedargs.dateset_type_colours, [-1 3], 1) , fNIRSTools.internal.verify.CellsAreNumericRange(namedargs.dateset_type_colours, 0, 1)} = cell(1,length(input_suffixes))
    namedargs.dateset_yaxis_limits {fNIRSTools.internal.verify.LengthMatch(namedargs.dateset_yaxis_limits, input_suffixes, 1, 1) , fNIRSTools.internal.verify.SizeInCells(namedargs.dateset_yaxis_limits, [-1 2], 1) , fNIRSTools.internal.verify.CellsAreNumeric(namedargs.dateset_yaxis_limits)} = cell(1,length(input_suffixes))
    
end
namedargs

%% Parse Name-Value Pairs
fNIRSTools.internal.parse_namedargs;

%% Prep
number_sets = length(input_suffixes);

%% Repeat Single Inputs
if length(dateset_normalize)==1
    dateset_normalize = repmat(dateset_normalize, [1 number_sets]);
end




