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

fnt = f([f.group]~='t');

%% Create line id for each line: vLine, hLine and mLine (missing lines)
nLinesSeen = length(fnt); %How many lines we have in the image

lid_vLines = 1:length(vLinePositions); 
lid_hLines = max(lid_vLines) + (1:length(hLinePositions)); 


%Missing lines can be any number that will make sure we have 6 lines present.
%Minimum of 6 lines garuntee unique identification
%lid_mLines = (max(lid_hLines) + 1)*ones(1,max(nLinesSeen-6,0)); %Missing lines are all the same id
nHAndVLines = length(vLinePositions) + length(hLinePositions);
lid_mLines = (max(lid_hLines) + 1)*ones(1,max(nLinesSeen-nHAndVLines,0)); %Missing lines are all the same id

lid = [lid_vLines lid_hLines lid_mLines];
%% Enomarate all possible line option classes

%Enomorate options for which lines are seen in the image
chooseOptions = nchoosek(lid,nLinesSeen); 
chooseOptions = unique(chooseOptions,'rows');

%Compute possible permutations for each option
sz = size(perms(chooseOptions(1,:)));
P = zeros(size(chooseOptions,1),sz(1),sz(2),'int8');

for i=1:size(chooseOptions,1)
    P(i,:,:) = perms(chooseOptions(i,:));
end
P = reshape(P,size(chooseOptions,1)*sz(1),sz(2));
P = unique(P,'rows');

%% Enomarate all options
%Remove enumerations that are not consistant, xLines (x=h or v) should be
%all assending or decending from left to right
iToKeep = ones(size(P,1),1);
for i=1:size(P)
    p=P(i,:);
    kp = 1;
    
    isv = ismember(p,lid_vLines); %Is p found in the v lines id
    pv = p(isv);
    
    if (length(pv)<2) %Too few lines, cant estimate using that
        kp = 0;
    else
        %Check assending decending consistancy
        d  = diff(pv);
        if (prod(d(1)==d)~=1)
            kp = 0;
        end
    end
    
    ish = ismember(p,lid_hLines); %Is p found in the v lines id
    ph = p(ish);
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
pos = [vLinePositions(:)'  hLinePositions(:)' 0]; %m line position is 0
groupAll = char( ismember(P,lid_vLines)*'v' + ismember(P,lid_hLines)*'h' + ismember(P,lid_mLines)*'-');
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
        scoreAll(i) = fitScore/sqrt(sum([fdln.group]~='-'));
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
    singlePlaneFit = spfCreateFromFiducialLines(fdln,pixelSize_um);
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
        