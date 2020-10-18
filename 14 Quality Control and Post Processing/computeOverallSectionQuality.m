function [qScore,...
    isOCTImageQualityGood, isHistologyImageQualityGood, alignmentQuality, ...
    areaOfQualityData_mm2 ...
    ] = computeOverallSectionQuality (input1)
% This function computes an overall quality score for the section. Possible
% USAGE (2 options):
%   [...] = computeOverallSectionQuality(sectionPath)
%   [...] = computeOverallSectionQuality(st) 
% INPUTS:
%   sectionPath - path to section folder in s3.
%   st - st structure
% OUTPUTS:
%   qScore - overall quality score:
%       NaN - cannot deterimne, not enugh information.
%       0 - Not useable for ML training, 
%       1 - Can be used for ML training
%       2 - Image quality & alignment are so good, this section can be used
%           to estimate OCT to histology performances.
%   sub scores:
%   isOCTImageQualityGood - true/false
%   isHistologyImageQualityGood - true/false
%   alignmentQuality - 1 to 3 (best)
%   areaOfQualityData_mm2 what is the area of overlap data

% Threshold
minimalAreaForSectionToBeQualified_mm2 = 0.12; %mm^2

%% Input checks
if ~exist('input1','var')
    input1 = [s3SubjectPath('07','LG') 'Slides/Slide03_Section03/'];
end

if ischar(input1)
    sectionPath = input1; % Input is a path
else
    st = input1; % Input is st structure
end

%% Initalize and load data
qScore = false;
isOCTImageQualityGood = NaN;
isHistologyImageQualityGood = NaN;
alignmentQuality = NaN;
areaOfQualityData_mm2 = NaN;

if exist('st','var')
    % Get varibles from st structure
    isOCTImageQualityGood = st.isOCTImageQualityGood;
    isHistologyImageQualityGood = st.isHistologyImageQualityGood;
    alignmentQuality = st.alignmentQuality;
    areaOfQualityData_mm2 = st.areaOfQualityData_mm2;
    isDermisVisibleInOCT = st.isDermisVisibleInOCT;
    pGelDetachedFromTissue = st.pGelDetachedFromTissueHistology;
    
    isAreaThreshold = areaOfQualityData_mm2 > minimalAreaForSectionToBeQualified_mm2;
    didUserFineTuneAlignmentAfterRectified = st.didUserFineTuneAlignmentAfterRectified;
    yAxisTolerance_um = st.yAxisTolerance_um;
else
    % Load sections
    %% Compute sub-scores based on QA questions
    % Load slide config
    slideConfigJson = awsReadJSON([sectionPath '/SlideConfig.json']);

    if ~isfield(slideConfigJson,'QAInfo')
        return; % Unable to determine score as QA info does not exist
    end
    
    isDermisVisibleInOCT = slideConfigJson.QAInfo.OCTImageQuality.IsDermisVisible;

    isOCTImageQualityGood = ...
        slideConfigJson.QAInfo.OCTImageQuality.IsOverallImageQualityGood & ...
        slideConfigJson.QAInfo.OCTImageQuality.IsEpitheliumVisible & ...
       ~slideConfigJson.QAInfo.OCTImageQuality.IsMostOfImageShadowed;

    isHistologyImageQualityGood = ...
       slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.IsOverallImageQualityGood & ...
      ~slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.WasTissueFolded & ...
       (slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.TissueBreakageOrHolesPresent < 0.8) ... No big holes in the tissue
      ;%(slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.WasGelDetachedFromTissue < 0.2); % Gel detachment shouldn't effect usablilty

    ql1 = slideConfigJson.QAInfo.AlignmentQuality.OverallAlignmentQuality;
    if ~slideConfigJson.QAInfo.AlignmentQuality.WasSurfaceUsedToAlign && ...
       ~slideConfigJson.QAInfo.AlignmentQuality.WereFeaturesInsideTissueUsedInAlignment
        ql2 = 1;
    elseif slideConfigJson.QAInfo.AlignmentQuality.WasSurfaceUsedToAlign && ...
           slideConfigJson.QAInfo.AlignmentQuality.WereFeaturesInsideTissueUsedInAlignment
        ql2 = 3;
    else
        ql2 = 2;
    end
    alignmentQuality = mean([ql1,ql2]);

    %% Compute what part of the section has both OCT and histology of the same spot
    if ~isfield(slideConfigJson,'alignedImagePath_Mask') 
        return; % Need a mask to continue
    end

    [msk, metaData] = yOCTFromTif(...
            [sectionPath slideConfigJson.alignedImagePath_Mask]);
        nPixelsWithGoodData = sum(msk(:)==0);
        pixelArea_um2 = diff(metaData.x.values(1:2))*diff(metaData.z.values(1:2));
        areaOfQualityData_mm2 = nPixelsWithGoodData*pixelArea_um2/1e3^2;

    isAreaThreshold = areaOfQualityData_mm2 > minimalAreaForSectionToBeQualified_mm2;

    %% Was fine alignment computed? if not it can be high quality :)

    if isfield(slideConfigJson.FM.singlePlaneFit_FineAligned,'wasRectified')
        wasRectified = slideConfigJson.FM.singlePlaneFit_FineAligned.wasRectified;
    else
        wasRectified = false;
    end

    didUserFineTuneAlignmentAfterRectified = false;
    if wasRectified
        % was rectified, did user fine tune alignment after?
        if isfield(slideConfigJson,'FMOCTAlignment')
            %The following line below is indicative if the user saved
            %the fine alignment after running
            tmp = slideConfigJson.FMOCTAlignment.planeDistanceFromOrigin_mm - slideConfigJson.FM.singlePlaneFit_FineAligned.d;
            didUserFineTuneAlignmentAfterRectified = abs(tmp) < 1e-3;
        end
    end
    
    yAxisTolerance_um = slideConfigJson.QAInfo.AlignmentQuality.YAxisToleranceMicrons;
    pGelDetachedFromTissue = slideConfigJson.QAInfo.HandEImageQuality_InOverlapArea.WasGelDetachedFromTissue;
end

%% Final basic score
isUsableInML = ...
        (isAreaThreshold==true) & ... Histology is close enugh to OCT such that many pixels exist in both
        (alignmentQuality > 1.5) & ... Alignment quality is high
        (isOCTImageQualityGood==true) & ... OCT quality is high
        (isHistologyImageQualityGood==true) & ... Histology quality is high
        (didUserFineTuneAlignmentAfterRectified==true); % User performed fine tuning
    
qScore = isUsableInML;

%% Update score if quality is particularly good
qScore(isUsableInML & ...
    (alignmentQuality >= 2.5) & ... High threshold quality
    (yAxisTolerance_um <=10 ) & ... Filter out sections that have high uncertanty about the accuracy of fine
                                ... alignment. Our hope is to be left with sections with defining features
                                ... that will help determine alignment accuracy
    isDermisVisibleInOCT & ... We would like dermis to be visible for high quality
    (pGelDetachedFromTissue<0.75) ... Not alot of detachement
    ) = 2;    
