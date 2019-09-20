function fo = identifyLinesAndAlignSlide_GoOverAllOptions(f,vLinePositions,hLinePositions,...
    pixelSize_um,octVolumeJson,histologyFluorescenceIm)
%This script goes over all options for feducial lines, chooses the best one
%and allows user to manually select if it wants another option
%INPUTS:
%   f - fiducialLines structure array
%   vLinePositions,hLinePositions - position (mm) of v&h lines
%OPTIONAL INPUTS: (for plotting)
%   pixelSize_um - pixel size of the slide image
%   octVolumeJson - JSON file of the OCT volume for plotting
%   histologyFluorescenceIm - background image of the histology picture
%OUTPUT:
%   fo - updated fdln

%% Input checks
if ~exist('pixelSize_um','var')
    pixelSize_um = 1;
end

if ~exist('octVolumeJson','var')
    octVolumeJson = [];
end

%% Enomarate all options
fnt = f([f.group]~='t');
nLinesSeen = length(fnt); %How many lines we have in the image
nLinesPhotobleached = length(vLinePositions) + length(hLinePositions);

P = perms(1:nLinesPhotobleached);
P = P(:,1:nLinesSeen); %All other lines are not visible in this image

%Remove raws that don't exist
P = unique(P,'rows');

%Remove enumerations that are not consistant, xLines (x=h or v) should be
%all assending or decending from left to right
iToKeep = ones(size(P,1),1);
for i=1:size(P)
    p=P(i,:);
    kp = 1;
    pv = p(p<=length(vLinePositions));
    
    if (length(pv)<2) %Too few lines, cant estimate using that
        kp = 0;
    else
        %Check assending decending consistancy
        d  = diff(pv);
        if (prod(d(1)==d)~=1)
            kp = 0;
        end
    end
    
    ph = p(p>length(vLinePositions));
    if (length(ph)<2) %Too few lines, cant estimate using that
        kp = 0;
    else
        %Check assending decending consistancy
        d  = diff(ph);
        if (prod(d(1)==d)~=1)
            kp=0;
        end
    end

    iToKeep(i) = kp;
end
P = P(iToKeep==1,:);

%% Try all options, keep score

%Generate structure to loop over all options
pos = [vLinePositions(:)'  hLinePositions(:)'];
groupAll = char( (P<=length(vLinePositions))*'v' + (P>length(vLinePositions))*'h');
posAll = pos(P);

%Outputs
scoreAll = zeros(size(P,1),1);
uAll = zeros(3,length(scoreAll));
vAll = uAll;
hAll = uAll;

for i=1:length(scoreAll)
    %Construct fdln
    fdln = fnt;
    for j=1:length(fdln)
        fdln(j).linePosition_mm = posAll(i,j);
        fdln(j).group = groupAll(i,j);
    end
    
    %Compute Fit
    try
        [u,v,h,fitScore] = fdlnEstimateUVHSinglePlane(fdln);
        
        %Save Data
        uAll(:,i) = u;
        vAll(:,i) = v;
        hAll(:,i) = h;
        scoreAll(i) = fitScore;
    catch
        scoreAll(i) = Inf;
    end
end

%% GUI Helping user select the best option
[~,ii] = sort(scoreAll);

global activeI;
activeI = 1;
while (true)

%Compute fit and plot it
fdln = fnt;
for j=1:length(fdln)
    fdln(j).linePosition_mm = posAll(ii(activeI),j);
    fdln(j).group = groupAll(ii(activeI),j);
end

if isstruct(octVolumeJson)
    singlePlaneFit = alignSignlePlane(fdln,pixelSize_um);
    plotSignlePlane(singlePlaneFit,fdln,histologyFluorescenceIm,octVolumeJson,false)
else
    break; %Just use the best fit, user didn't give us any plotting info
end

%Plot all options
figure(220);
semilogy(ii(activeI),scoreAll(ii(activeI)),'r+');
hold on;
semilogy(scoreAll,'o');
hold off;
title('Scores for All options');
grid on;
legend([],groupAll(ii(activeI),:));

%UI Control
h = uicontrol('Position',[10 10 100 20],'String','Prev Socre',...
              'Callback','global activeI; activeI = max(activeI-1,1);uiresume(gcbf)');
h = uicontrol('Position',[120 10 100 20],'String','Keep This One',...
              'Callback','global activeI; activeI = NaN;uiresume(gcbf)');
h = uicontrol('Position',[230 10 100 20],'String','Next Score',...
              'Callback','global activeI; activeI = activeI+1;uiresume(gcbf)');
uiwait(gcf); 

if (isnan(activeI))
    close;
    break;
    %We are done
end
end


%% Return updated fdln
ft = f([f.group]=='t');
fo = [ft(:); fdln(:)];
        