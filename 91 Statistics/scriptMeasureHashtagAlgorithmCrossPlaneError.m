% This script compares cross plane distance of algorithm vs fine alignment.
%% Inputs 

libraryNames = {'LC','LD','LE','LF','LG'};

%% Load data
st = loadStatusReportByLibrary(libraryNames);

%% Filter
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

% Pull data
goodI = find(goodI);
d_StackAlignment = st.sectionDistanceFromOCTOrigin3StackAlignment_um(goodI);
d_FineAlignment = st.sectionDistanceFromOCTOrigin4FineAlignment_um(goodI);
d_FineAlignmentTolerance = st.yAxisTolerance_um(goodI);
subjectNames = st.subjectNames(goodI);
sectionNames = st.sectionNames(goodI);

sectionId = cell(size(sectionNames));
for i=1:length(sectionId)
    sn = strrep(sectionNames{i},'_','-');
    sn = strrep(sn,'Slide','Sl');
    sn = strrep(sn,'Section','Se'); 
    sectionId{i} = [' ' subjectNames{i} '-' sn];
end
%% Plot 

if true
figure(1);
m = max(abs([d_StackAlignment(:);d_FineAlignment(:)]));
errorbar(d_StackAlignment,d_FineAlignment,d_FineAlignmentTolerance,'o')
hold on;
plot([-m m],[-m m]);
plot([-m m],[-m m]+20,'k--');
plot([-m m],[-m m]-20,'k--');
hold off;
xlim([-m m]);
xlabel('Stack Alignment (# Algorithm Prediction) [\mum]');
ylabel('Fine Alignment (Human Fine Alignment) [\mum]');
legend('data','Perfect Agreement',sprintf('\\pm20\\mum'),'location','south')
ylim([-m m]);
grid on;
title(['Does fine-alignment agree with stack-alignment?' newline '(computed on high quality images & high quality alignment)'])
end

diff_distance = d_StackAlignment-d_FineAlignment;
figure(2);
s = std(diff_distance); % mum
m = median(diff_distance); % mum
out = abs(diff_distance-m) > s*2.5*100; % Disable outlier filtration
s = std(diff_distance(~out));
m = mean(diff_distance(~out));
n = 1:length(diff_distance);
errorbar(diff_distance,n,d_FineAlignmentTolerance,'o','horizontal')
hold on;
plot([0 0],n([1 end]));
plot(+m*[1 1],n([1 end]),'r--');
plot(m+s*[1 1],n([1 end]),'k--');
plot(m-s*[1 1],n([1 end]),'k--');
errorbar(diff_distance(out),n(out),d_FineAlignmentTolerance(out),'ob','horizontal') %Plot outliers with slightly different color
hold off;
xlabel('Stack Alignment - Fine Alignment [\mum]');
legend('Section Data','Perfect Agreement',sprintf('Mean: %.1f\\mum', m),sprintf('Std: \\pm%.0f\\mum',s),'location','southwest')
grid on;
title(['Does fine-alignment agree with stack-alignment?' newline '(computed on high quality images & high quality alignment)'])
yticks(n);
yticklabels(sectionId);
axis ij

figure(3);
a = histogram(diff_distance,30);
title(sprintf('Std Error: \\pm%.0f\\mum',s))
hold on;
plot(m+s*[1 1],[0 max(a.Values)],'k--');
plot(m-s*[1 1],[0 max(a.Values)],'k--');
hold off
grid on; 
ylabel('# of Sections');
xlabel('Distance Between Stack Alignment to Human Fine Tuning [\mum]');

%% Compute aligment accuracy post fine alignment
h = st.yAxisTolerance_um;
h(h>s) = s;
h(isnan(h)) = [];
plot(h)
mean(h)

