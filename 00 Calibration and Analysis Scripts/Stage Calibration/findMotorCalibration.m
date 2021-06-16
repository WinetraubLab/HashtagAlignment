% This script analyzes photobleached lines to find motor calibration


%% Inputs
photobleachImagePath = 's3://delazerdamatlab/Users/Aidan/Photobleach Lines Experiments/Photobleach 6.16.2021/Experiment_TileScan_001_Merging001_z0_ch00.tif';
imageResolution = 2.8; % microns per pixel. 1x is 2.8 microns per pixel

lineRatio = 5; % Ratio between two long lines vs long line to its short line
               % This ratio is motorMovement/d in scanTarget_StageCalibration.m

mmToDeviceUnitsX = 33998; %100000/2.9151; % Get this number from ThrolabsImagerStage.cpp
mmToDeviceUnitsY = 33998; %100000/2.9151; % Get this number from ThrolabsImagerStage.cpp
               
%% Read Image
dsIm = imageDatastore(photobleachImagePath);
im = dsIm.read();

%% Rotate - Course
figure(1);
imshow(im);
title('Please mark one of the streight lines in the image. Click enter to continue.');
[x,y] = getline();

if (length(x) ~= 2)
    error('Please select only 2 points');
end

alpha0 = atan2(diff(y),diff(x))*180/pi;

%% Rotate - Fine Tune
im_roi = im(round(min(y):max(y)),round(min(x):max(x)));

alphas = linspace(alpha0-10,alpha0+10,200);
score = zeros(size(alphas));
figure(11);
for i=1:length(alphas)
    im_tmp = imrotate(im_roi,alphas(i),'bilinear','crop');
    sig = mean(im_tmp,2);
    
    % Smooth
    f = fft(sig);
    f(2:round(end*0.9)) = 0;
    sig = abs(ifft(f));
    
    % Score
    score(i) = max(abs(diff(sig)));
    
    % Plot
    subplot(2,2,1);
    imshow(im_tmp);
    hold on;
    plot([1 size(im_tmp,2)],size(im_tmp,1)*0.5*[1 1],'--r');
    hold off;
    subplot(2,2,2);
    plot(diff(sig));
    title('Optimizing');
    subplot(2,2,[3 4]);
    plot(alphas,score);
    [~,j] = max(score);
    hold on;
    plot(alphas(j),score(j),'o');
    plot(alpha0*[1 1],[0 max(score)],'--');
    hold off;
    grid on;
    legend('Scores','Best','User Selected Angle');
    title('Searching for Best Score');
    
    pause(0.05);
end

[~,j] = max(score);
alpha = alphas(j);

% Compute rotate angle and rotate image
im = imrotate(im,alpha);

%% Do the work
processSingleMotor(im,'X',imageResolution,lineRatio,mmToDeviceUnitsX);
processSingleMotor(im,'Y',imageResolution,lineRatio,mmToDeviceUnitsY);


%% Process A Single Motor
function processSingleMotor(im,directionStr,imageResolution,lineRatio,mmToDeviceUnits)

directionStr = upper(directionStr);
directionStr = directionStr(1);

%% Select area with lines
figure(2);
imshow(im);
switch(directionStr)
    case 'X'
        title('Please selet X Motor Lines (two solid lines)');
    case 'Y'
        title('Please selet Y Motor Lines (one solid and one dashed lines)');
end
roi = round(getrect());

% Add x% on height to capture a baseline without photobleaching area
%roi(2) = round(roi(2) - 0.1*roi(4));
%roi(4) = round(roi(4) + 0.2*roi(4));

im_x = im(roi(2)+(1:roi(4)),roi(1)+(1:roi(3)));
imshow(im_x);
%% Choose which are the good line set
[pt1,pt2] = findLineSeperation(im_x, imageResolution); %pt1 - long lines, pt2 - short lines

%% Make sure line ordering is correct
if length(pt1) == length(pt2)
    % Make sure line order is long,short,long,short
    if abs(mean(pt1-pt2)) > 0.5*mean(diff(pt1))
        %Flip order
        pt1(1) = [];
        pt2(end) = [];
    end
else
    % Figure out which line needs to be deleted
    if length(pt1) > length(pt2)
        if abs(mean(pt1(2:end)-pt2)) > 0.5*mean(diff(pt1))
            pt1(end) = [];
        else
            pt1(1) = [];
        end
    else
        if abs(mean(pt1-pt2(2:end))) > 0.5*mean(diff(pt1))
            pt2(1) = [];
        else
            pt2(end) = [];
        end
    end
end

%% Develop a linear model
pti = 1:length(pt1);
p1 = polyfit(pti,pt1,1);
p2 = polyfit(pti,pt2,1);

%%
figure(3);
subplot(2,2,1+2*(directionStr=='Y'));
plot(pti,pt1,'o',pti,polyval(p1,pti),'-',...
     pti,pt2,'o',pti,polyval(p2,pti),'-');
xlabel('Line Number');
ylabel('Pixel Position');
title([directionStr ' Motor How Well line positions are linear?']);
subplot(2,2,2+2*(directionStr=='Y'));
e = [(polyval(p1,pti)-pt1),(polyval(p2,pti)-pt2)]*imageResolution;
histogram(e);
xlabel('\mum');
title([directionStr ' Motor Linear Fit Residual Error']);

meanLargeLineDiff_pix = mean([p1(1) p2(1)]);
meanLargeLineSmallLineDiff_pix = abs(mean(pt2-pt1));
lineRatio_measured = meanLargeLineDiff_pix/meanLargeLineSmallLineDiff_pix;

fprintf('%s Motor: Distance Between Large Lines is %.4f X Distance Between Large Line to Small Line.\n\tWe would like this ratio to be %.4f.\n',...
    directionStr,lineRatio_measured);
fprintf('Please correct mmToDeviceUnits from %.8g to NEW VALUE: %.8g\n',...
    mmToDeviceUnits,mmToDeviceUnits*lineRatio/lineRatio_measured);

end

%% Find line seperation functions
function [ptPrimary,ptSecondary] = findLineSeperation(im_roi, imageResolution)

pt1 = findLineSeperation_sub(im_roi,imageResolution); % One direction
pt2 = findLineSeperation_sub(im_roi',imageResolution); % The other direction

% Make user select sets

imshow(im_roi);
hold on;
% Plot 4 sets of lines
for i=1:2:length(pt1)
    plot(pt1(i)*[1 1],[1 size(im_roi,2)],'Color','r','LineWidth',1);
end
for i=2:2:length(pt1)
    plot(pt1(i)*[1 1],[1 size(im_roi,2)],'Color','g','LineWidth',1);
end
for i=1:2:length(pt2)
    plot([1 size(im_roi,1)],pt2(i)*[1 1],'Color','b','LineWidth',1);
end
for i=2:2:length(pt2)
    plot([1 size(im_roi,1)],pt2(i)*[1 1],'Color','w','LineWidth',1);
end
hold off;

%% Ask Input
primaryColor = inputdlg('Which Line Set is the Primary Long Lines? (r,g,b,w)');
if isempty(primaryColor)
    error('Select Set');
end
secondaryColor = inputdlg('Which Line Set is the Secondary Short Lines? (r,g,b,w)');
if isempty(secondaryColor)
    error('Select Set');
end

switch(lower(primaryColor{1}))
    case 'r'
        ptPrimary = pt1(1:2:end);
    case 'g'
        ptPrimary = pt1(2:2:end);
    case 'b'
        ptPrimary = pt2(1:2:end);
    case 'w'
        ptPrimary = pt2(2:2:end);
end

switch(lower(secondaryColor{1}))
    case 'r'
        ptSecondary = pt1(1:2:end);
    case 'g'
        ptSecondary = pt1(2:2:end);
    case 'b'
        ptSecondary = pt2(1:2:end);
    case 'w'
        ptSecondary = pt2(2:2:end);
end
end

function pt1 = findLineSeperation_sub(im_roi,imageResolution)


% Get data and smooth
d = mean(im_roi,1);
f = fftshift(fft(d));
flt = ones(size(f));
flt(round(end/2+(-2:2)))=0; % Delete DC Component
flt(1:round(end*0.15))=0;
flt(round(end*0.85):end)=0;
d = abs(ifft(fftshift(f.*flt)));

% Find line positions
[d1_pt,pt1] = findpeaks(d, ...
    'MinPeakProminence',20 ... Gray scale units
    ...'MinPeakWidth',20/imageResolution ... Min distance between peaks should be ~20 microns
    );

% Plot
figure(225);
plot(d); 
hold on; 
plot(pt1,d1_pt,'*');
hold off;
end