function recomputeSlideAlignment(slidePath)
% This function recomputes slide  alignment 
% Written at Jan 25, 2020.

%% Load Data
if ~exist('slidePath','var')
    slidePath = [s3SubjectPath('04','LE') 'Slides/Slide03_Section02/'];
end

slideConfigJsonPath = [slidePath 'SlideConfig.json'];
jj = awsReadJSON(slideConfigJsonPath);

%% Add parameter specifing if Histology to bright filed was successfull
if isfield(jj,'FMHistologyAlignment')
    jj.FMHistologyAlignment.wasAlignmentSuccessful = true;
else
    disp('Skipping this slide, no Histology - Brightfield alignment.');
    return;
end

%% Reverse engineer the parameters.
if false
if ~isfield(jj.FM,'singlePlaneFit') || isempty(jj.FM.singlePlaneFit)
    disp('Skipping this slide, not single plane fit.');
    return;
end

singlePlaneFit = jj.FM.singlePlaneFit;
u = singlePlaneFit.u;
v = singlePlaneFit.v;
h = singlePlaneFit.h;
n = singlePlaneFit.n;

v_ = (n - h(2)+h(1)*u(2)/u(1))/(v(2)-v(1)*u(2)/u(1));
singlePlaneFitNew = spfCreateFromUVH(u,v,h,v_,jj.FM.pixelSize_um);
jj.FM.singlePlaneFit = singlePlaneFitNew;
end

%% Upload
awsWriteJSON(jj,slideConfigJsonPath);