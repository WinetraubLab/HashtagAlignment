function fdln = fdlnIdentifyLinesByStackInterpolation(fdln,vLinePositions,hLinePositions,fdlnStack)
%This function tries to identify fiducial line structure based on other
%slides in the stack that are identified and can be used for interpolation
%INPUTS:
%   fdln - fiducial line structure array
%   vLinePositions - crossing points of vertical lines (x=0, y=c) [mm]
%   hLinePositions - crossing points of horizontal lines (x=c, y=0) [mm]
%   fdlnStack - cell array containing fiducial lines of all the slides in
%   the stack (including fdln). This function assumes positions of all
%   slides are more or less equally spaced.
%
%OUTPUTS:
%   update fiducial line structure, does not update fdlnStack.
%NOTICE:
%   fdln must also be a member of fdlnStack cell array

%% Find fdln in fdlnStack
%Find fdln in fdlnStack
isIt = cellfun(@(x)isequal(x,fdln),fdlnStack);
if (sum(isIt) ~= 1)
    error('Could not find fdln in stack');
else
    fdlnI = find(isIt,1,'first');
end

isTissueInterface = lower([fdln.group]) == 't'; %Find which lines are tissue interface

%% Find average stack parameters
fdlnsToUse = find(cellfun(@fdlnIsLineIdentified,fdlnStack) == 1);
us = zeros(3,length(fdlnsToUse));
vs = us;
hs = us;

for i=1:length(fdlnsToUse)
   f = fdlnStack{fdlnsToUse(i)};
   [u,v,h] = fdlnEstimateUVHSinglePlane(f);
   
   us(:,i) = u;
   vs(:,i) = v;
   hs(:,i) = h;
end

%Compute stack average direction
uStack = median(us,2);
vStack = median(vs,2);
n = cross(uStack,vStack); n = n / norm(n);

%Compute h component prepandicular to the plane
hdotn = dot(hs,repmat(n,[1 size(hs,2)]));
p = polyfit(fdlnsToUse,hdotn,1);
if false
    plot(fdlnsToUse,hdotn,fdlnsToUse,polyval(p,fdlnsToUse));
end

%% Find parameters for our particular Stack
u = uStack;
v = vStack;
h = n*polyval(p,fdlnI);

%Average v_pix to act upon
v_ = mean(cellfun(@mean,{fdln(~isTissueInterface).v_pix}));

xPlaneUFunc_pix = @(vint,c)(-v(1)/u(1)*vint-h(1)/u(1)+c/u(1)); %x=c
yPlaneUFunc_pix = @(vint,c)(-v(2)/u(2)*vint-h(2)/u(2)+c/u(2)); %y=c

%% Find each line's position in the picture (just u direction)
vLineU = xPlaneUFunc_pix(v_,vLinePositions);
hLineU = yPlaneUFunc_pix(v_,hLinePositions);

lineU = [vLineU(:)' hLineU(:)'];
lineGroup = [repmat('v',[1 length(vLineU)]) repmat('h',[1 length(vLineU)])];
linePos = [vLinePositions(:)' hLinePositions(:)'];

%Organize lines from left to right
[~,iSort] = sort(lineU);
lineU = lineU(iSort);
lineGroup = lineGroup(iSort);
linePos = linePos(iSort);

%Fiducial Line Position
lineUMarked  = cellfun(@mean,{fdln(~isTissueInterface).u_pix});

%% Match fdln to predicted line positon
if (length(lineUMarked) > length(lineU))
    error('Too many marked lines');
elseif (length(lineUMarked) < length(lineU))

    %Find all possible ways to remove lines, compute which one is the most
    %likely lines to be matched
    C = nchoosek(1:length(lineU),length(lineU)-length(lineUMarked));
    scores = zeros(size(C,1),1);

    %Looop over all options to remove lines, see what will be the score for
    %each option
    dlineUMarked = diff(lineUMarked(:)');
    for i=1:size(C,1)
        l=lineU;
        l(C(i,:)) = []; %Remove specific lines (acording to the permutation)
        dl = diff(l(:))';

        scores(i) = sum(abs(dlineUMarked-dl));
    end

    %Choose the best option
    if (~isempty(scores))
        j = find(scores == min(scores),1,'first');
        lineGroup(C(j)) = []; %Remove the lines that make most scense 
        linePos(C(j)) = [];
    end
else
    %We have the right amount of lines. Do nothing
end

%% Update fdln
k=1;
for i=1:length(fdln)
    if (fdln(i).group == 't')
        continue;
    else
        fdln(i).group = lineGroup(k);
        fdln(i).linePosition_mm = linePos(k);
        k=k+1;
    end
end