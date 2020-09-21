function goodI = getSectionsWithBestAlignment(st)
% This function returns the indexes of sections that have the very best
% alignments

goodI = ones(size(st.sectionNames),'logical');

% Filter out sections with no stack alignment
goodI(isnan(st.sectionDistanceFromOCTOrigin3StackAlignment_um)) = false;

% Filter out sections with no fine alignment
goodI(~st.isCompletedOCTHistologyFineAlignment) = false;

% Filter out sections that have high uncertanty about the accuracy of fine
% alignment. Our hope is to be left with sections with defining features
% that will help determine alignment accuracy
goodI(st.yAxisTolerance_um > 10) = false;

% Use only the highest fine aligned samples alignment quality.
goodI(st.alignmentQuality < 2.5) = false;

% Use only high quality OCT and histology data, just to double check that
% alignment is real (be more conservative)
goodI(st.isOCTImageQualityGood==0 | ...
     st.isHistologyImageQualityGood==0) = false;
goodI(isnan(st.isOCTImageQualityGood) | ...
     isnan(st.isHistologyImageQualityGood)) = false;

% Use only sections that were fine alignemd using features inside tissue.
%goodI(st.wereFeaturesInsideTissueUsedInAlignment == 0) = false; TBD ADD