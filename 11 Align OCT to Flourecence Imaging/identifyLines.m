function photobleachedLines = identifyLines(photobleachedLines,linePosGroup1,lineGroup1Name,linePosGroup2,lineGroup2Name)
%This function tries to identify line ids based on their ratios.
%INPUTS:
%   photobleachedLines - lines to be identified, structure should contain
%   u_pix, v_pix will update the rest
%   linePosGroup1 - line positions (along 1 dimension line) of group 1 of
%       lines. Example (-0.100mm,0,0.200mm). Position should be mm!
%   linePosGroup2 - optional, same as linePosGroup1.
%   lineGroup1Name - name 'h' or 'v' for example
%
%OUTPUTS:
%   update photobleachedLines structure

%% Input checks
if ~exist('linePosGroup2','var')
    linePosGroup2 = [];
end

pls = photobleachedLines;

%% Preprocess positions
lineU = [pls.u_pix]'; %(line #, point in line)
lineV = [pls.v_pix]'; %(line #, point in line)

%Compute line centers
lineUm = mean(lineU,2);
lineVm = mean(lineV,2);
p = polyfit(lineUm,lineVm,1); %Line that crosses all photobleached lines

%Compute intersection points between line p and all photobleached lines
lineUi = zeros(size(lineUm));
lineVi = lineUi;
for i=1:length(lineUi)
    if diff(lineU(i,[1 end])) ~= 0
        pi = polyfit(lineU(i,:),lineV(i,:),1);
        lineUi(i) = -(pi(2)-p(2))/(pi(1)-p(1));
    else %Vertical line
        lineUi(i) = mean(lineU(i,:));
    end
    lineVi(i) = polyval(p,lineUi(i));
    
    if false
        x = lineUi(i) + (-100:100);
        plot(x,polyval(p,x),x,polyval(pi,x),lineUi(i),lineVi(i),'o',lineUm(i),lineVm(i),'o')
    end
end

%Sort lines so that they will appear in order
[~,iSort] = sort(lineUi);
lineUi = lineUi(iSort);
lineVi = lineVi(iSort);

%Measure distance between consequitive lines
d = zeros(length(lineUi)-1,1);
for i=1:length(d)
   d(i) = sqrt( (diff(lineUi(i+[0 1]))).^2 + (diff(lineVi(i+[0 1]))).^2);
end

dr = d(1:(end-1))/d(2:end);

%% Encode lines ratios
ratios = zeros(2*(length(linePosGroup1)-2 + length(linePosGroup2)-2),1);
allLineId_Group = zeros(size(ratios));
allLineId_LineNumbers = zeros(length(ratios),3);
allLineId_Pos = zeros(length(ratios),3);

ri = 1;

for i=2:(length(linePosGroup1)-1)
    
    ratios(ri) = abs(linePosGroup1(i-1)-linePosGroup1(i))/abs(linePosGroup1(i+1)-linePosGroup1(i));
    ratios(ri+1) = 1/ratios(ri);
    
    allLineId_Group(ri+(0:1)) = lineGroup1Name;
    allLineId_LineNumbers(ri,:) = [i-1 i i+1];
    allLineId_Pos(ri,:) = linePosGroup1(allLineId_LineNumbers(ri,:));
    allLineId_LineNumbers(ri+1,:) = [i+1 i i-1];
    allLineId_Pos(ri+1,:) = linePosGroup1(allLineId_LineNumbers(ri+1,:));
    ri = ri+2;
end
for i=2:(length(linePosGroup2)-1)
    
    ratios(ri) = abs(linePosGroup2(i-1)-linePosGroup2(i))/abs(linePosGroup2(i+1)-linePosGroup2(i));
    ratios(ri+1) = 1/ratios(ri);
    
    allLineId_Group(ri+(0:1)) = lineGroup2Name;
    allLineId_LineNumbers(ri,:) = [i-1 i i+1];
    allLineId_Pos(ri,:) = linePosGroup2(allLineId_LineNumbers(ri,:));
    allLineId_LineNumbers(ri+1,:) = [i+1 i i-1];
    allLineId_Pos(ri+1,:) = linePosGroup2(allLineId_LineNumbers(ri+1,:));
    ri = ri+2;
end
    
%% For each line that we have, what is it identity 
lineId_Group = zeros(size(lineUi))*NaN;
lineId_LineNumbers = zeros(size(lineUi))*NaN;
lineId_Pos = zeros(size(lineUi))*NaN;

for i=1:length(dr)
    correspondingLinesI = i:(i+2);
    
    tmp = abs(ratios/dr(i)-1);
    j = find(tmp == min(tmp));
    
    if ( ...
        nansum(lineId_Group(correspondingLinesI)-allLineId_Group(j)) ~= 0 ||             ...Identification of one of the lines is ambiguis (group)
        nansum(lineId_LineNumbers(correspondingLinesI)-allLineId_LineNumbers(j,:)') ~= 0 ...Identification of one of the lines is ambiguis (group)
        )
        error('Line Identification Ambivalent (line I): %d %d %d',correspondingLinesI(1),correspondingLinesI(2),correspondingLinesI(3));
    end
    
    lineId_LineNumbers(correspondingLinesI) = allLineId_LineNumbers(j,:)';
    lineId_Group(correspondingLinesI)       =  allLineId_Group(j);
    lineId_Pos(correspondingLinesI)         = allLineId_Pos(j,:)';
end

%% Copy output
for i=1:length(lineId_Group)
    pls(iSort(i)).group = char(lineId_Group(i));
    pls(iSort(i)).linePosition_mm = lineId_Pos(i);
end
photobleachedLines = pls;
    