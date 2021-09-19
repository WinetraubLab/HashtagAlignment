% This script analyzes photobleached lines to find motor calibration
% This script runs on the data of photobleached using this script: scanTarget_StageRepeatability

%% Inputs
photobleachImagePath = 's3://delazerdamatlab/Users/Aidan/Photobleach Lines Experiments/Photobleach 6.18.2021/Gel2_Scan1/Experiment_TileScan_001_Merging001_z0_ch00.tif';
imageResolution = 2.89; % microns per pixel. 1x is 2.88 microns per pixel

%% Read Image
awsSetCredentials();
% Any fileDatastore request to AWS S3 is limited to 1000 files in 
% MATLAB 2021a. Due to this bug, we have replaced all calls to 
% fileDatastore with imageDatastore since the bug does not affect imageDatastore. 
% 'https://www.mathworks.com/matlabcentral/answers/502559-filedatastore-request-to-aws-s3-limited-to-1000-files'
dsIm = imageDatastore(photobleachImagePath);
im = dsIm.read();

% SP5 images are flipped compared to project coordinate system
im = fliplr(im);

%% Find best rotation
figure(1);
subplot(1,1,1);
imshow(im);

title('Mark the center square');
r=getrect();
pad = 70; %padding
r = r + [-pad -pad 2*pad 2*pad]; % buffer
im_roi = im(round(r(2)+(1:r(4))),round(r(1)+(1:r(3))));

% Tuning loops
alpha = 45;
alphaRanges=[45,5];
for tuneI=1:length(alphaRanges)
    alphas = linspace(...
        alpha-alphaRanges(tuneI), ...
        alpha+alphaRanges(tuneI),100);
    
    score = zeros(size(alphas));
    for i=1:length(alphas)
        im_tmp = imrotate(im_roi,alphas(i),'bilinear','crop');
        im_tmp = im_tmp(pad:(end-pad),pad:(end-pad));
        
        sig1 = mean(im_tmp,1);
        sig2 = mean(im_tmp,2);
        
        % Smooth sig1
        f = fftshift(fft(sig1));
        f(round(end/2 +(-7:7)))=0;
        sig1 = abs(ifft(fftshift(f)));
        
        % Smooth sig2
        f = fftshift(fft(sig2));
        f(round(end/2 +(-7:7)))=0;
        sig2 = abs(ifft(fftshift(f)));

        % Score
        score(i) = max(abs([sig1(:); sig2(:)]));
        
        % Plot
        subplot(2,2,1);
        imshow(im_tmp);
        hold on;
        plot([1 size(im_tmp,2)],size(im_tmp,1)*0.5*[1 1],'--r');
        hold off;
        subplot(2,2,2);
        plot(sig1);
        hold on;
        plot(sig2);
        hold off;
        title('Optimizing');
        subplot(2,2,[3 4]);
        plot(alphas,score);
        [~,j] = max(score);
        hold on;
        plot(alphas(j),score(j),'o');
        hold off;
        grid on;
        legend('Scores','Best');
        title('Searching for Best Score');

        pause(0.05);
    end
    
    [~,j] = max(score);
    alpha = alphas(j);
end

% 90 degree modifications
while(1)
    imshow(imrotate(im_roi,alpha));
    a = questdlg('Would You like to Rotate by 90 degrees to get "L" Shape?');
    switch(a)
        case 'Yes'
            alpha = alpha + 90;
        case 'No'
            break;
        otherwise
            return;
    end
end

% Output is alpha
im = double(imrotate(im,alpha));

%% Find Center Square
subplot(1,1,1);
imagesc(im); colormap gray;
title('Mark the center square');
r=getrect();

%Get points
subplot(1,2,1);
imagesc(im);
xlim([r(1) r(1)+r(3)]);
ylim([r(2) r(2)+r(4)]);
a = gca;
title('Get points in the order on the right, Click Enter When Done');
subplot(1,2,2);
plotMap();
hold on;
plot(0,0,'or'); text(0,0,' 1');
plot(1,0,'or'); text(1,0,' 2');
plot(0,1,'or'); text(0,1,' 3');
plot(-1,0,'or'); text(-1,0,' 4');
plot(0,-1,'or'); text(0,-1,' 5');
hold off;
[x,y] = getpts(a);

if (length(x)~=5)
    error('We need only 5 points');
end

p1=polyfit(x([4,1,2]),y([4,1,2]),1);
p2=polyfit(y([5,1,3]),-x([5,1,3]),1);
img2OCTAngle_deg = nanmean(atan([p1(1) p2(1)])*180/pi);

%% Other Squares
squares = {'Right','Top','Left','Bottom'};
xc = zeros(size(squares));
yc = zeros(size(squares));

for i=1:length(squares)
    subplot(1,1,1);
    imagesc(im); colormap gray;
    title(['Mark the ' squares{i} ' square (make sure L shape is upright)']);
    r=getrect();
    
    subplot(1,2,1);
    imagesc(im); colormap gray;
    xlim([r(1) r(1)+r(3)]);
    ylim([r(2) r(2)+r(4)]);
    a = gca;
    title('Mark the Center');
    subplot(1,2,2);
    plotMap();
    hold on;
    plot(0,0,'or'); 
    hold off;
    [xc(i),yc(i)] = getpts(a);
end

% Add the center square
xc = [x(1) xc];
yc = [y(1) yc]; 

% Find the angle
p1=polyfit(xc([4,1,2]),yc([4,1,2]),1);
p2=polyfit(yc([5,1,3]),-xc([5,1,3]),1);
img2Stage_deg = mean(atan([p1(1) p2(1)])*180/pi);

%% Plot Results
subplot(1,1,1);
imagesc(im);
colormap gray
d = max(x-x(1))*1.2;
D = max(xc-xc(1));
xlim([min(xc)-d,max(xc)+d]);
ylim([min(yc)-d,max(yc)+d]);

hold on;
plot(xc(1) + D*[-1 1],yc(1) + D*tan(img2OCTAngle_deg*pi/180)*[-1 1]);
plot(xc(1) + D*[-1 1],yc(1) + D*tan(img2Stage_deg*pi/180)*[-1 1]);
hold off;
legend('OCT Coordinate System','Stage Coordinate System');
title(sprintf('Difference OCT->Stage is %.2f Degrees',-img2OCTAngle_deg+img2Stage_deg));

function plotMap()
plot([-1 1]*1.2,[0 0],'k');
hold on;
plot([0 0],[-1 1]*1.2,'k');
plot([-1 -1 1 1 -1],[-1 1 1 -1 -1],'k');
plot([-1.2 -1.2 0],[1 -1.2 -1.2],'k');
hold off;
axis equal;
xlim([-2 2]);
end