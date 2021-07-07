% This script estimates light depth of penetration to the tissue

%% Load library statistics
libraryNames = s3GetAllLibs();

% Load
st = loadStatusReportByLibrary(libraryNames);

% Investigate only healthy & fresh samples
goodI = st.isFreshHumanSample ;%& st.isSampleHealthy;

%% Plot statistics

figure
histogram(st.octDepthOfPenetration_um(goodI));
nanmean(st.octDepthOfPenetration_um(goodI))
