function histologyInstructionsEmptyDistanceFromFullFaceToOCTOrigin(subjectPath)
% This function finds places where distance from full face to oct origin is
% empty in histology instructions and fill up the gap such that distance is
% such that center slice will be at OCT center.
% Written at Feb 28, 2020.

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('01','LE');
end

%% Load Json
jsonPath = [subjectPath '/Slides/StackConfig.json'];
stackConfig = awsReadJSON(jsonPath);

%% Loop over iterations in stack config, update if needed
didMakeAChange = false;
for i=1:length(stackConfig.histologyInstructions.iterations)
    hi = stackConfig.histologyInstructions.iterations(i);
    
    if isempty(hi.estimatedDistanceFromFullFaceToOCTOrigin_um)
        m = mean(hi.sectionDepthsRequested_um);
        hi.estimatedDistanceFromFullFaceToOCTOrigin_um = m;
        stackConfig.histologyInstructions.iterations(i) = hi;
        didMakeAChange = true;
    end
end

%% Upload
if ~didMakeAChange
    disp('No change is needed, skipping');
    return; % No need to continue
end

awsWriteJSON(stackConfig,jsonPath);
