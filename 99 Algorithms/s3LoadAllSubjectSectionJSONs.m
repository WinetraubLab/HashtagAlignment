function json = s3LoadAllSubjectSectionJSONs(varargin)
% This function loads all JSONs to one structure for us to reference
%   json = s3LoadAllSubjectSectionJSONs(subjectPath [, sectionName, parameters ...)
% INPUTS:
%   - subjectPath - path to subject.
%   - sectionName - example: 'Slide01_Section02'. If empty, will only load
%       subject releated jsons / remove slide related jsons
% PARAMETERS:
%   'json' - eneter a json from perviuse load to save some time
% OUTPUTS:
%   - json - collection of all relevant JSON files.

%% Input handle

p = inputParser;
addRequired(p,'subjectPath',@ischar);
addOptional(p,'sectionName', '' ,@ischar);

addParameter(p,'json',[])

parse(p,varargin{:});
in = p.Results;
subjectPath = in.subjectPath;
sectionName = in.sectionName;
json = in.json;

%% Subject related Jsons

if ~awsExist([subjectPath '/Subject.json'],'file')
    error('Subject %s does not exist', subjectPath);
end

json = loadSingleJSON([subjectPath '/Subject.json'], 'subject', json);
json = loadSingleJSON([subjectPath '/OCTVolumes/ScanConfig.json'], 'scanConfig', json);
json = loadSingleJSON([subjectPath '/Slides/StackConfig.json'], 'stackConfig', json);

if isempty(sectionName)
    % Remove section related jsons
    json = loadSingleJSON('', 'sectionIterationConfig', json);
    json = loadSingleJSON('', 'slideConfig', json);
    json.sectionIndexInStack = NaN;
    json.sectionIteration = NaN;
    return; % We are done!
end

%% Iteration realated Jsons

% Figure out which iteration is this section in
if ~isempty(json.stackConfig.data)
    isThisSection = cellfun(@(x)(strcmp(x,sectionName)), ...
        json.stackConfig.data.sections.names);
    
    if any(isThisSection)
        if sum(isThisSection) ~= 1
            error('Multiple sections with the same name, doesnt make sense');
        end
        json.sectionIteration = json.stackConfig.data.sections.iterations(isThisSection);
        sectionIndexInStack = find(isThisSection);
    else
        %Unknown iteration
        json.sectionIteration = NaN;
    end
end

if ~isnan(json.sectionIteration)
    iterationPath = sprintf('%s/OCTVolumes/StackVolume_Iteration%d/TifMetadata.json',...
        subjectPath,json.sectionIteration);
else
    iterationPath = '';
end
json = loadSingleJSON(iterationPath, 'sectionIterationConfig', json);
if ~isempty(json.sectionIterationConfig.data)
    json.sectionIterationConfig.path = [fileparts(json.sectionIterationConfig.path) '/'];
    json.sectionIterationConfig.data = json.sectionIterationConfig.data.metadata; % Go in for the meta data
    json.sectionIterationConfig.data_um = yOCTChangeDimensionsStructureUnits(json.sectionIterationConfig.data,'um');
end

%% Section related Jsons

json = loadSingleJSON(...
    sprintf('%s/Slides/%s/SlideConfig.json',subjectPath,sectionName), ...
    'slideConfig', json);


json.sectionIndexInStack = sectionIndexInStack;
    
%% Base function for loading every json file.
function json = loadSingleJSON(jsonPath, fieldName, json)

% Empty input
if isempty(jsonPath)
    json.(fieldName).path = '';
    json.(fieldName).data = [];
    return;
end


if  isfield(json,fieldName) && ...
    isfield(json.(fieldName),'data') && ...
   ~isempty(json.(fieldName).data)
    % Field already exist, no need to add it.
    return;
end

% Set Path
jsonPath = awsModifyPathForCompetability(jsonPath);
json.(fieldName).path = jsonPath;

% Load
if awsExist(jsonPath,'file')
    json.(fieldName).data = awsReadJSON(jsonPath);
else
    json.(fieldName).data = [];
end