function recomputeSlideAlignment(slidePath)
% This function recomputes slide  alignment 
% Written at Jan 25, 2020.

%% Load Data
%slidePath = [s3SubjectPath('04') 'Slides/Slide01_Section02/']

slideConfigJsonPath = [slidePath 'SlideConfig.json'];
jj = awsReadJSON(slideConfigJsonPath);

%% Reverse engineer the parameters.
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

%% Upload
jj.FM.singlePlaneFit = singlePlaneFitNew;
awsWriteJSON(jj,slideConfigJsonPath);