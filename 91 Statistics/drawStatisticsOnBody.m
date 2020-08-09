function [regionNames, regionNumberOfDataPoints] = drawStatisticsOnBody (bodyPartsNames, numberOfDataPoints, bodyPartsNames2, numberOfDataPoints2)
% Inputs:
%   bodyPartsNames - cell of strings with body parts names
%   numberOfDataPoints - number of points per body part, optional. Will
%       mark as one score per body part if not specified.
%   bodyPartsNames2, numberOfDataPoints2 - same as bodyPartsNames but for
%       second class

%bodyPartsNames = {'Right Thigh','Thigh','Left Forehead'}';

%% Input checks
if ~exist('numberOfDataPoints','var') || isempty(numberOfDataPoints)
    numberOfDataPoints = ones(size(bodyPartsNames));
end

if ~exist('bodyPartsNames2','var')
    bodyPartsNames2 = {};
end
if ~exist('numberOfDataPoints2','var')  || isempty(numberOfDataPoints2)
    numberOfDataPoints2 = ones(size(bodyPartsNames2));
end

%% Convert body parts to position on reference image
[x,y,p,positionNames] = bodyPartsNames2Positions(bodyPartsNames, numberOfDataPoints);
[x2,y2,p2] = bodyPartsNames2Positions(bodyPartsNames2, numberOfDataPoints2);
if length(x) ~= length(x2)
    error('Was expecting same length');
end
pTotal = p+p2;

%% Load reference image
currentFileFolder = fileparts(mfilename('fullpath'));
bodyFilePath = [currentFileFolder '\body.png']; %Source: https://www.vectorstock.com/royalty-free-vector/cartoon-color-human-body-anatomy-set-vector-27280733
imBody = imread(bodyFilePath); 
bodyX = linspace(-1,1,size(imBody,2));
bodyY = linspace(0,size(imBody,1)/size(imBody,2)*2,size(imBody,1));

%% Plot
set(gcf,'Color',[1 1 1]);
image('XData',bodyX,'YData',bodyY,'CData',imBody);
axis equal
axis ij
axis off
ylim(bodyY([1 end]))
text(0,bodyY(end),'Dot location doesn''t reflect laterality','FontSize',8,'HorizontalAlignment','Center')
hold on;

%Size scale marker
sizeScaleFnc = @(a)(12*a/max(p) + 2);
sizeScale = linspace(min(p(p>0)),max(p),3); %sizeScale(1) = [];
sizeScale = fliplr(sizeScale);
if (min(sizeScale) > 5)
    mn = 5;
else
    mn = 1;
end
sizeScale = round(sizeScale/mn)*mn;
for i=1:length(sizeScale)
    
    % Set color of size scale markers to black if 2 types exist
    if ~isempty(p2)
        c = 'k';
    else
        c = 'b';
    end
    plot(i,-10,'ow','MarkerFaceColor',c,'MarkerSize',sizeScaleFnc(sizeScale(i)));
end

% Plot dots (1)
for i=1:length(p)
   if (p(i) == 0)
       continue;
   end
  
   plot(x(i),y(i),'ow','MarkerFaceColor','b','MarkerSize',sizeScaleFnc(p(i)));
end

% Plot dots (2)
for i=1:length(p2)
   if (p2(i) == 0)
       continue;
   end
  
   plot(x2(i)-0.02,y2(i),'ow','MarkerFaceColor','r','MarkerSize',sizeScaleFnc(p2(i)));
end

hold off;

% Create legend
ltxt = ['legend(' sprintf('''%.0f'',',sizeScale) '''location'',''south'',''orientation'',''horizontal'');'];
[legh,objh] = eval(ltxt);

% Text for unknown position
isUnknown = find(cellfun(@(x)(strcmpi(x,'unknown')),positionNames),1,'first');
if (pTotal(isUnknown) > 0)
    % Write unknown text only if we have data with unknown position
    text(x(isUnknown), y(isUnknown),'  Unknown');
end

[~,i] = sort(p,'descend');
regionNames = positionNames(i);
regionNumberOfDataPoints = p(i);

function [x,y,p,positionNames] = bodyPartsNames2Positions(bodyPartsNames, numberOfDataPoints)
% This function converts body parts names and number of data points to x,y
% position and number of points on that coordinate
% x,y - positions on body image
% p - number of poinrs in that position

%% Reference positions 
positions = {...
....Name    Side      X Pos  Y Pos    
    'Thigh' ''        0.324 3.749 ; ...
    'Forehead' ''    -0.084 0.328 ; ... 
    'Cheek' ''       -0.200 0.665 ; ...
    'Nose'  ''       -0.049 0.629 ; ...
    'Lip'   ''       -0.049 0.806 ; ...
    'Scalp' ''        0.129 0.257 ; ...
    'Jaw'   ''        0.138 0.780 ; ...
    'Eyebrow' ''     -0.218 0.443 ; ...
    'Shin'  ''        0.440 5.131 ; ...
    'Neck'  ''        0.099 0.968 ; ...
    'Chest' ''       -0.048 1.533 ; ...
    'Back'  ''       -0.048 1.533 ; ...
    'Ear'   ''       -0.360 0.567 ; ...
    'Clavicle' ''    -0.253 1.117 ; ...
    'forearm' ''      0.778 2.499 ; ...
    'hand' ''        -0.911 3.101 ; ...
    'Unknown' ''     -0.280 6.150 ; ...
    };

%% Replace names that mean the same
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'mandible','jaw')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'nasal','nose')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'mid antihelix','ear')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'preauricular','ear')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'lower leg','shin')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'temple','forehead')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'arm','forearm')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'foreforearm','forearm')),bodyPartsNames,'UniformOutput',false);

%% Fill in positions
p = zeros(size(positions,1),1); %Points per position
for i=1:length(bodyPartsNames)
    bp = bodyPartsNames{i};
    ndp = numberOfDataPoints(i);
    
    %Figure out direction
    if contains(lower(bp),'left')
        positionsMask = cellfun(@(x)(strcmpi(x,'left')),positions(:,2));
    elseif contains(lower(bp),'right')
        positionsMask = cellfun(@(x)(strcmpi(x,'right')),positions(:,2));
    else
        %Unknown side
        positionsMask = ones(size(positions,1),1,'logical');
    end
    positionsMask = positionsMask | cellfun(@isempty,positions(:,2)); % Add parts that dont have sides
    
    % Filter by body part
    positionsMask = positionsMask.*cellfun(@(x)(contains([' ' bp],[' ' x],'IgnoreCase',true)),positions(:,1));
    
    % Unknown position mask
    if ~any(positionsMask)
        positionsMask = cellfun(@(x)(contains('unknown',x,'IgnoreCase',true)),positions(:,1));
        error('Unknown position %s',bp);
    end
    positionsMask = positionsMask == 1;
    
    % Devide score by number of fits
    p(positionsMask) = p(positionsMask) + ndp/sum(positionsMask);
end

%% Convert to x-y grid with value for each point
x = cell2mat(positions(:,3));
y = cell2mat(positions(:,4));

positionNames = positions(:,1);