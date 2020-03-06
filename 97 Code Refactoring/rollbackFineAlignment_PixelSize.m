function rollbackFineAlignment_PixelSize(slidePath)
% This function roll back the fine alignment pixel size to stack mean size
% Written at Jan 25, 2020.

%% Load Data
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('07','LE') 'Slides/Slide03_Section02/'];
end

slidePath = awsModifyPathForCompetability([slidePath '/']);
[~,slideName] = fileparts([slidePath(1:(end-1)) '.a']);
slideConfigJsonPath = [slidePath '/SlideConfig.json'];
jj = awsReadJSON(slideConfigJsonPath);

%% Reverse engineer the parameters.
if ~isfield(jj.FM,'singlePlaneFit_FineAligned') || isempty(jj.FM.singlePlaneFit_FineAligned)
    disp('Skipping this slide, not single plane fit.');
    return;
end

stackConfigJsonPath = [slidePath '../StackConfig.json'];
jjStack = awsReadJSON(stackConfigJsonPath);

iteration = jjStack.sections.iterations(...
    cellfun(@(x)(strcmp(x,slideName)),jjStack.sections.names));

avgHistologyPixelSize_um = jj.FM.pixelSize_um / ...
    jjStack.stackAlignment(iteration).scaleFactor;
avgHistologyPixelSize_mm = avgHistologyPixelSize_um*1e-3;

%% Load and update single plane
singlePlaneFit = jj.FM.singlePlaneFit_FineAligned;
u = singlePlaneFit.u;
v = singlePlaneFit.v;
h = singlePlaneFit.h;

u = u/norm(u)*avgHistologyPixelSize_mm;
v = v/norm(v)*avgHistologyPixelSize_mm;

v_ = singlePlaneFit.vTypical;
singlePlaneFitNew = spfCreateFromUVH(u,v,h,v_,jj.FM.pixelSize_um);

%% Upload
jj.FM.singlePlaneFit_FineAligned = singlePlaneFitNew;
awsWriteJSON(jj,slideConfigJsonPath);