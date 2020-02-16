function drawStatisticsOnBody (bodyPartsNames, numberOfDataPoints)
% Inputs:
%   bodyPartsNames - cell of strings with body parts names
%   numberOfDataPoints - number of points per body part, optional. Will
%       mark as one score per body part if not specified.

%bodyPartsNames = {'Right Thigh','Thigh','Left Forehead'}';

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
    'Ear'   ''       -0.360 0.567 ; ...
    'Unknown' ''     -0.280 6.150 ; ...
    };

%% Input checks
if ~exist('numberOfDataPoints','var')
    numberOfDataPoints = ones(size(bodyPartsNames));
end

%% Replace names that mean the same
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'mandible','jaw')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'nasal','nose')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'mid antihelix','ear')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'preauricular','ear')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'lower leg','shin')),bodyPartsNames,'UniformOutput',false);
bodyPartsNames = cellfun(@(x)(strrep(lower(x),'temple','forehead')),bodyPartsNames,'UniformOutput',false);

%% Load reference image
currentFileFolder = fileparts(mfilename('fullpath'));
bodyFilePath = [currentFileFolder '\body.png']; %Source: https://www.vectorstock.com/royalty-free-vector/cartoon-color-human-body-anatomy-set-vector-27280733
imBody = imread(bodyFilePath); 
bodyX = linspace(-1,1,size(imBody,2));
bodyY = linspace(0,size(imBody,1)/size(imBody,2)*2,size(imBody,1));

%% Fill in positions
p = zeros(size(positions,1),1);
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
    positionsMask = positionsMask.*cellfun(@(x)(contains(bp,x,'IgnoreCase',true)),positions(:,1));
    
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

%% Plot
set(gcf,'Color',[1 1 1]);
image('XData',bodyX,'YData',bodyY,'CData',imBody);
axis equal
axis ij
axis off
ylim(bodyY([1 end]))

hold on;

%Size scale
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
    plot(i,-10,'ow','MarkerFaceColor','b','MarkerSize',sizeScaleFnc(sizeScale(i)));
end

% Plot dots
for i=1:length(p)
   if (p(i) == 0)
       continue;
   end
  
   plot(x(i),y(i),'ow','MarkerFaceColor','b','MarkerSize',sizeScaleFnc(p(i)));
   
end
hold off;

% Create legend
ltxt = ['legend(' sprintf('''%.0f'',',sizeScale) '''location'',''south'',''orientation'',''horizontal'');'];
[legh,objh] = eval(ltxt);

% Text for unknown
isUnknown = cellfun(@(x)(strcmpi(x,'unknown')),positions);
text(positions{isUnknown,3},positions{isUnknown,4},'  Unknown');