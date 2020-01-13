function stackConfig = scGenerateStackConfig(varargin)
% This function generates stack config structure based on the inputs below.
%PARAMETERS:
%   'appendToSC' - stack config structure that you would like to append
%       data to.
%   'sampleID' - the sample identification eg. 'LA-01'
% Information specific for the iteration we are adding:
%   'iterationNumber' - the iteration currently been inputed. If left empty,
%       assumed first iteration (=1)
%   'sectionDepthsRequested_um' array containing the positions of planes
%       compared to last full face
%   'estimatedDistanceFromFullFaceToOCTOrigin_um' - see notes below
%   'operator' - see notes below
%   'date' - see notes below, can be numeric or string. if left empty will
%       set for today's date.
%   'section_names' - sections names for this iteration. If kept empty,
%       will set for the default naming convention according to sections
%       per slide
%   'startCuttingAtDotSide' - see notes
% Histology Instructions Parameters (see notes section below for explenation)
%   'histoKnife_sectionsPerSlide'
%   'histoKnife_sectionThickness_um'
%   'histoKnife_thicknessOf5umSlice_um'
%   'histoKnife_thicknessOf25umSlice_um'

%% Input Processing
p = inputParser;

addParameter(p,'appendToSC',[]);
addParameter(p,'sampleID',[]);

% Iteration
addParameter(p,'iterationNumber',1);
addParameter(p,'sectionDepthsRequested_um',[]);
addParameter(p,'estimatedDistanceFromFullFaceToOCTOrigin_um',[]);
addParameter(p,'operator',[]);
addParameter(p,'date',[]);
addParameter(p,'startCuttingAtDotSide',[]);
addParameter(p,'section_names',[]);

% Histo knife defenitions
addParameter(p,'histoKnife_sectionsPerSlide',3);
addParameter(p,'histoKnife_sectionThickness_um',5);
addParameter(p,'histoKnife_thicknessOf5umSlice_um',5*2);
addParameter(p,'histoKnife_thicknessOf25umSlice_um',25*1.7);

if (length(varargin) == 1)
    %Try parsing the first one as a cell
    in = varargin{1};
    parse(p,in{:});
else
    parse(p,varargin{:});
end
in = p.Results;

%% Parse General Parameters
% Set base stack structure to be the one that we append to (if exists)
if ~isempty(in.appendToSC)
    stackConfig = in.appendToSC;
end

% Version
stackConfig.version = 1.2;

% Sample ID (if doesn't already exist)
if ~isfield(stackConfig,'sampleID') || isempty(stackConfig.sampleID)
    stackConfig.sampleID = in.sampleID;
end

%% Histology knife (if doesn't already exist)
if  ~isfield(stackConfig,'histologyInstructions') || ...
    ~isfield(stackConfig.histologyInstructions,'histoKnife')
    stackConfig.histologyInstructions.histoKnife.sectionsPerSlide = in.histoKnife_sectionsPerSlide;
    stackConfig.histologyInstructions.histoKnife.sectionThickness_um = in.histoKnife_sectionThickness_um;
    stackConfig.histologyInstructions.histoKnife.thicknessOf5umSlice_um = in.histoKnife_thicknessOf5umSlice_um;
    stackConfig.histologyInstructions.histoKnife.thicknessOf25umSlice_um = in.histoKnife_thicknessOf25umSlice_um;
end

%% Iteration
ii = in.iterationNumber;

% Date
if isempty(in.date)
    in.date = now;
end
if ~isnumeric(in.date)
    in.date = datenum(in.date);
end
in.date = datestr(in.date,'mmm dd, yyyy');

%Figur out dot side
if (isempty(in.startCuttingAtDotSide))
    % Figure out dot side from prev iterations
    if isfield(stackConfig,'histologyInstructions') && isfield(stackConfig.histologyInstructions,'iterations')
        prevDotSide = [stackConfig.histologyInstructions.iterations(:).startCuttingAtDotSide];
        prevDotSide = unique(prevDotSide);
        if (length(prevDotSide) ~= 1)
            error('Prev iterations sometimes cut at the dot side, sometimes don''t, unsure if this iteration starts at the dot side. Please specify by defning "startCuttingAtDotSide"');
        end
        in.startCuttingAtDotSide = prevDotSide;
    else
        error('Unsure which side to start cut, please define "startCuttingAtDotSide"');
    end
end

% Add data
stackConfig.histologyInstructions.iterations(ii).startCuttingAtDotSide = in.startCuttingAtDotSide;
stackConfig.histologyInstructions.iterations(ii).sectionDepthsRequested_um = in.sectionDepthsRequested_um;
stackConfig.histologyInstructions.iterations(ii).estimatedDistanceFromFullFaceToOCTOrigin_um = in.estimatedDistanceFromFullFaceToOCTOrigin_um;
stackConfig.histologyInstructions.iterations(ii).operator = in.operator;
stackConfig.histologyInstructions.iterations(ii).date = in.date;

%% Notes
stackConfig.histologyInstructions.notes = [...
    'This structure defines how histologist should cut our sample. ' newline ...
    'histoKnife defines the process of cutting, how many sections per slides and their thickness. ' newline ...
    '.thicknessOf5umSlice_um and .thicknessOf25umSlice_um specify our best estimates of when we request a 5um slice (for sectioning process) or 25um slice (for shaving tissue until first section) how much the machine cuts. Turns out the machine cuts more than we expected.' newline ...
    'iterationSpec defines what we would like from histologist each time we send the block to sectioning, each spec defines one iteration where we get a few slides.' newline ...
    '.sectionDepthsRequested_um is how deep to cut from full face (0 been the current full face).' newline ...
    '.startCuttingAtDotSide which side to start cutting, dot side (1) or opposite to the dot side (-1).' newline ...
    '.estimatedDistanceFromFullFaceToOCTOrigin_um, at the time when instructions were given what was the best estimate for the distance from the current full face (depth = 0) to where OCT origin is at. Keep empty if unknown.' newline ...
    '.operator who made the call of how to cut.' newline  ...
    '.date when section was cut.' newline ...
    ];

%% Sections Names and Iterations

% Override existing sections
if isfield(stackConfig,'sections') && isfield(stackConfig.sections,'iterations')
    sI = stackConfig.sections.iterations == ii;
    stackConfig.sections.names(sI) = [];
    stackConfig.sections.iterations(sI) = [];
end

% Number of sections in this iteration
if (isempty(in.section_names) || (...
    length(in.section_names) == ...
    length(stackConfig.histologyInstructions.iterations(ii).sectionDepthsRequested_um) ...
    ))
    nSectionsToAdd = length(stackConfig.histologyInstructions.iterations(ii).sectionDepthsRequested_um);
else
    error('Unsure how many sections in this iteration, according to section names, this iteration has %d sections, according to sectionDepthsRequested %d sections',length(in.section_names),length(stackConfig.histologyInstructions.iterations(ii).sectionDepthsRequested_um));
end

% Set the expected next name
if ii == 1
    nextSlide = 1;
    nextSection = 1;
else
    str = stackConfig.sections.names{...
        find(stackConfig.sections.iterations==ii-1,1,'last')};
    nextSlide = interpertSectionName(str);
    nextSlide = nextSlide+1; %Start form the slide after
    nextSection = 1;
end

% Loop over sections to add and find the next one
if ~isfield(stackConfig,'sections') || ~isfield(stackConfig.sections,'iterations') || ~isfield(stackConfig.sections,'names')
    stackConfig.sections.names = {};
    stackConfig.sections.iterations = [];
end
for i=1:nSectionsToAdd
    
    % Check naming matches what we expect
    if ~isempty(in.section_names)
        [slide, section] = interpertSectionName(in.section_names{i});
        if (slide ~= nextSlide || section ~= nextSection)
            error('Was expecting section %d in iteration %d to be slide=%d, section=%d. But got slide=%d, section=%d.',i,ii,nextSlide,nextSection,slide,section);
        end
    end
    
    % Add this slide & iteration
    stackConfig.sections.iterations(end+1) = ii;
    stackConfig.sections.names{end+1} = sprintf('Slide%02d_Section%02d',nextSlide,nextSection);
    
    % Profress one section
    nextSection = nextSection + 1;
    if (nextSection > stackConfig.histologyInstructions.histoKnife.sectionsPerSlide)
        nextSection = 1;
        nextSlide = nextSlide + 1;
    end
end

% Sort by iteration
[~,iSort] = sort(stackConfig.sections.iterations);
stackConfig.sections.iterations = stackConfig.sections.iterations(iSort);
stackConfig.sections.names = stackConfig.sections.names(iSort);

% Check no duble names
if (length(stackConfig.sections.names) ~= length(unique(stackConfig.sections.names)))
    error('Some stack names are repeated..');
end

end
function [slide,section] = interpertSectionName(str)
    res = sscanf(str,'Slide%d_Section%d');
    slide = res(1);
    section = res(2);
end