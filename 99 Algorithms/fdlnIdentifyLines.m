function fdln = fdlnIdentifyLines(fdln,vLinePositions,hLinePositions)
%This function tries to identify fiducial line structure based on the distance ratios.
%INPUTS:
%   fdln - fiducial line structure array
%   vLinePositions - crossing points of vertical lines (x=0, y=c) [mm]
%   hLinePositions - crossing points of horizontal lines (x=c, y=0) [mm]
%
%OUTPUTS:
%   update fiducial line structure

%% Preprocess positions of fdln, extract ratios
f = fdln;
lineU = [f.u_pix]'; %(line #, point in line)
lineV = [f.v_pix]'; %(line #, point in line)

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

%% Encode lines ratios of the groups we have
ratios = zeros(2*(length(vLinePositions)-2 + length(hLinePositions)-2),1);
allLineId_Group = zeros(size(ratios));
allLineId_LineNumbers = zeros(length(ratios),3);
allLineId_Pos = zeros(length(ratios),3);

ri = 1;

for i=2:(length(vLinePositions)-1)
    
    ratios(ri) = abs(vLinePositions(i-1)-vLinePositions(i))/abs(vLinePositions(i+1)-vLinePositions(i));
    ratios(ri+1) = 1/ratios(ri);
    
    allLineId_Group(ri+(0:1)) = 'v';
    allLineId_LineNumbers(ri,:) = [i-1 i i+1];
    allLineId_Pos(ri,:) = vLinePositions(allLineId_LineNumbers(ri,:));
    allLineId_LineNumbers(ri+1,:) = [i+1 i i-1];
    allLineId_Pos(ri+1,:) = vLinePositions(allLineId_LineNumbers(ri+1,:));
    ri = ri+2;
end
for i=2:(length(hLinePositions)-1)
    
    ratios(ri) = abs(hLinePositions(i-1)-hLinePositions(i))/abs(hLinePositions(i+1)-hLinePositions(i));
    ratios(ri+1) = 1/ratios(ri);
    
    allLineId_Group(ri+(0:1)) = 'h';
    allLineId_LineNumbers(ri,:) = [i-1 i i+1];
    allLineId_Pos(ri,:) = hLinePositions(allLineId_LineNumbers(ri,:));
    allLineId_LineNumbers(ri+1,:) = [i+1 i i-1];
    allLineId_Pos(ri+1,:) = hLinePositions(allLineId_LineNumbers(ri+1,:));
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
    f(iSort(i)).group = char(lineId_Group(i));
    f(iSort(i)).linePosition_mm = lineId_Pos(i);
end
fdln = f;
    