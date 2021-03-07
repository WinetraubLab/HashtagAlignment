% This script marks a slide as rectified, if it was a mistake in the past

%% Inputs 
subjectPath = s3SubjectPath('58','LGC');

%% Get all slides and determine rectify status
stackConfig = awsReadJSON([subjectPath '/Slides/StackConfig.json']);

% Load all slide configs
slideConfigs = cell(size(stackConfig.sections.names));
slideConfigsJsonPaths = cell(size(stackConfig.sections.names));
for i=1:length(slideConfigsJsonPaths)
    nm = stackConfig.sections.names{i};
    
    slideConfigJsonPath = [subjectPath '/Slides/' nm '/SlideConfig.json'];
    slideConfigsJsonPaths{i} = slideConfigJsonPath;
    if awsExist(slideConfigJsonPath,'file')
        slideConfigs{i} = awsReadJSON(slideConfigJsonPath);
        %nm
    end
end

%% Find each slide fine alignment staus
wasRectified = zeros(size(slideConfigsJsonPaths),'logical')*NaN;
for i=1:length(slideConfigsJsonPaths)
    if ( ...
            ~isempty(slideConfigs{i}) && ...
            isfield(slideConfigs{i}.FM, 'singlePlaneFit_FineAligned') ...
        )
        if isfield(slideConfigs{i}.FM.singlePlaneFit_FineAligned, 'wasRectified')
            wasRectified(i) = slideConfigs{i}.FM.singlePlaneFit_FineAligned.wasRectified;
        else
            wasRectified(i) = false;
        end
    end
end

% Find iterations where a slide was missed
for i=1:max(stackConfig.sections.iterations)
    ii = stackConfig.sections.iterations == i;
    if ~any(ii)
        wasRectifiedIteration = NaN;
        continue;
    else
        wasRectifiedIteration = wasRectified(stackConfig.sections.iterations == i)'
        {stackConfig.sections.names{stackConfig.sections.iterations == i}}
        
        if ~all(isnan(wasRectifiedIteration)) && nanmax(wasRectifiedIteration) ~= nanmin(wasRectifiedIteration)
            warning('Rectfy issue here');
        end
    end
end
    



    