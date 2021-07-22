% This script calibrates optical path correction.
% Be sure to scan a flat surface using scanTarget function

%% Inputs
%experimentPath = s3SubjectPath('2019-11-30 Imaging Flat Surface On Motorized Stage','',true);
experimentPath = s3SubjectPath('2021-07-21 Imaging Flat Surface On Optic Table','',true);

json = awsReadJSON([experimentPath 'ScanInfo.json']);

isLoadOCTVolumeToPresentUser = true; % Set to false for faster execution, without loading OCT volume.

%% Pre-processing #1 compute interface position
for sI = 1:length(json.octFolders)
    octPath = awsModifyPathForCompetability([experimentPath json.octFolders{sI} '/']);
    
    if ~awsExist([octPath 'interfaceZPositions.mat'])
        fprintf('%s Finding Interface Z Position... (%d of %d)\n',datestr(datetime),sI,length(json.octFolders));
        
        % Load scan Abs and dimensions
        [scanAbs,dim] = yOCTFromTif([octPath 'scanAbs.tif']);
        
        % z dimensions
        minZ = 20;
        z = dim.z.values(minZ:end); %[um]

        % Compute interface position by looking for max
        [~,interfaceZ] = max(scanAbs(minZ:end,:,:),[],1);
        interfaceZ = z(shiftdim(squeeze(interfaceZ),1)); %um (y,x)

        % Save output results along side with dimensions
        yOCT2Mat(interfaceZ,[octPath 'interfaceZPositions.mat'],dim);
    end 
end

%% Pre-processing #2 fit a polynomial to all
mdl = @(x,y,a)(a(1) + a(2)*x + a(3)*y + a(4)*x.^2 + a(5)*y.^2 + a(6)*x.*y);
fprintf('%s Fit polynomials... \n',datestr(datetime));
for sI = 1:length(json.octFolders)
    octPath = awsModifyPathForCompetability([experimentPath json.octFolders{sI} '/']);
    
    % Load data
    [interfaceZ,dim] = yOCTFromMat([octPath 'interfaceZPositions.mat']);
    
    % Set dimensions
    x = dim.x.values; %um
    y = dim.y.values; %um
    z = dim.z.values; %um
    
    %% Fit 2D polynomial (least squares)
    [xx,yy] = meshgrid(x,y);
    A = [ones(numel(xx),1) xx(:) yy(:) xx(:).^2 yy(:).^2 xx(:).*yy(:)];
    
    % Get rid of obvious outliers, those who are very far for median
    interfaceZ_med = medfilt2(interfaceZ,[50 50],'symmetric');
    isOutlier = abs(interfaceZ_med-median(interfaceZ_med(:))) > 200; %mum
    
    % Fine tune to find more outliers
    a =  A(~isOutlier,:)\interfaceZ_med(~isOutlier); 
    e = mdl(xx(:),yy(:),a)-interfaceZ(:);
    isOutlier = abs(e) > 20; %mum

    % Fit without the outliers
    a =  A(~isOutlier,:)\interfaceZ(~isOutlier); %Polynomial values

    % Print coefients
    fprintf('\n');
    fprintf('# Z Correction (microns) Polynomial for correcting optical path.\n')
    fprintf('# Coefficients are [x y x^2 y^2 x*y] where x,y are positions in microns.\n')
    fprintf('OpticalPathCorrectionPolynomial = [%.4e, %.4e, %.4e, %.4e, %.4e]\n',a(2:end));
    fprintf('a0 Component: %.1f[um]\n',a(1));
    fprintf('\n');
    
    %% Figure out peak positions and Save
    % Peak Position
    xPeak = -a(2)/(2*a(4));
    yPeak = -a(3)/(2*a(5));

    % Index of Peak Position
    [~,yPeakI] = min(abs(yPeak-y));
    [~,xPeakI] = min(abs(xPeak-x));

    % Save parameters
    fit.info = 'interfaceZ uints is (um), dimentions are y(um),x(um). p(1)+p(2)*x+p(3)*y+p(4)*x^2+p(5)*y^2+p(6)*x*y';
    fit.p = a;
    fit.xPeak = xPeak;
    fit.xPeakI = xPeakI;
    fit.yPeak = yPeak;
    fit.yPeakI = yPeakI;
    awsWriteJSON(fit,[experimentPath 'interfaceZPositions_PolyFit.json']);
    
    %% Plot fit & save
    f = figure(sI);
    set(f,'units','normalized','outerposition',[0 0 1 1]);

    subplot(2,2,1)
    interfaceZ2 = interfaceZ;
    interfaceZ2(isOutlier) = NaN;
    imagesc(x,y,interfaceZ2);
    %colormap gray;
    colorbar;
    hold on;
    plot(xPeak,yPeak,'+b');
    plot(x([1 end]),yPeak*[1 1],'--b');
    plot(xPeak*[1 1],y([1 end]),'--b');
    text(xPeak,yPeak,sprintf('Peak Point\n(%.0f\\mum,%.0f\\mum)',xPeak,yPeak));
    hold off;
    xlabel('x[\mum]');
    ylabel('y[\mum]');
    [~,probeName] = fileparts(json.octProbePath);
    title(sprintf('Interface Depth (Data) [\\mum] (%s)',probeName));
    grid on;
    legend(sprintf('Polyfit: %.0f+%.1ex+%.1ey+%.1ex^2+%.1ey^2+%.1exy',a(1),a(2),a(3),a(4),a(5),a(6)),...
        'location','south')

    subplot(2,2,2);
    plot(x,interfaceZ(:,xPeakI),'b+');
    hold on;
    plot(x,mdl(x(xPeakI),y,a),'k','LineWidth',3);
    ylim([min(interfaceZ2(:)) max(interfaceZ2(:))]+50*[-1 1]);
    hold off
    grid on;
    axis ij;
    title('Peak Point X Direction Snapshot');
    xlabel('y[\mum]');
    ylabel('z[\mum]');
    legend('Data','Fit');

    subplot(2,2,4);
    e = mdl(xx(~isOutlier),yy(~isOutlier),a)-interfaceZ(~isOutlier);
    histogram(e,200);
    xlim(round(std(e)*10)*[-1 1]);
    title('Error From Model');
    xlabel('Error [\mum]');
    ylabel('Probability');
    grid on;
    
    % Temporary text before image loading is completed
    subplot(2,2,3);
    plot(0,0,'*');
    text(0,0,'Processing ...');
    pause(0.1);
    
    subplot(2,2,3);
    if isLoadOCTVolumeToPresentUser
        if ~exist('scanY','var') || true
            scanY = yOCTFromTif([octPath 'scanAbs.tif'],'yI',yPeakI);
        end
        imagesc(x,z,scanY);
        hold on;
    end
    plot(x,interfaceZ(yPeakI,:),'b+');
    hold on;
    plot(x,mdl(x,y(yPeakI),a),'k','LineWidth',3);
    ylim([min(interfaceZ2(:)) max(interfaceZ2(:))]+50*[-1 1]);
    hold off
    grid on;
    axis ij;
    title('Peak Point Y Direction Snapshot');
    xlabel('x[\mum]');
    ylabel('z[\mum]');
    pause(0.1);
    
    saveas(f,'interfaceZPositions_PolyFit.png');
    awsCopyFileFolder('interfaceZPositions_PolyFit.png',experimentPath);
end

%% Compate oct probe calibration
fprintf('%s Compare Flat Surface to Probe Calibration... \n',datestr(datetime));
octPath = awsModifyPathForCompetability([experimentPath json.octFolders{1} '/']);

if ~exist('xx','var')
    [interfaceZ,dim] = yOCTFromMat([octPath 'interfaceZPositions.mat']);
    x = dim.x.values; %um
    y = dim.y.values; %um
    z = dim.z.values; %um
    [xx,yy] = meshgrid(x,y);
end

% Compute difference
pf = awsReadJSON([octPath '../interfaceZPositions_PolyFit.json']);
p = pf.p;
p_ref = json.octProbe.OpticalPathCorrectionPolynomial;
d = mdl(xx,yy,p) - mdl(xx,yy,[0;p_ref]);
d = d-mean(d(:));

% Plot
f=figure(100);
set(f,'units','normalized','outerposition',[0 0 1 1]);
subplot(1,2,1);
imagesc(d);
axis equal;
xlabel('x[\mum]');
ylabel('y[\mum]');
title('Difference: This Calibration - OCT Probe [\mum]');
colorbar;
grid on;
subplot(1,2,2);
hist(d(:),100);
xlabel('Difference [\mum]');
ylabel('Probability');
grid on;

saveas(f,'interfaceZPositions_CompareToProbeCalibration.png');
awsCopyFileFolder('interfaceZPositions_CompareToProbeCalibration.png',experimentPath);

%% Compare between different z positions in the calibration)
if length(json.octFolders) > 1
    fprintf('%s Compare Between different Depth In Calibration... \n',datestr(datetime));

    interfZ = zeros(size(xx,1),size(xx,2),length(json.octFolders));
    yPeakIs = zeros(length(json.octFolders),1);
    for sI = 1:length(json.octFolders)
        octPath = awsModifyPathForCompetability([experimentPath json.octFolders{sI} '/']);
        pf = awsReadJSON([octPath 'interfaceZPositions_PolyFit.json']);
        p = pf.p;
        yPeakIs(sI) = pf.yPeakI;
        
        interfZ(:,:,sI) = mdl(xx,yy,p);
    end
    
    % Compute mean and deviation from the mean
    m = squeeze(mean(mean(interfZ,2),1));
    interfZ_NoMean = zeros(size(interfZ));
    for i=1:length(m)
        interfZ_NoMean(:,:,i) = interfZ(:,:,i)-m(i);
    end
    interfZSpan = max(interfZ_NoMean,[],3) - min(interfZ_NoMean,[],3);
    
    f=figure(101);
    set(f,'units','normalized','outerposition',[0 0 1 1]);
    subplot(2,2,1);
    imagesc(interfZSpan);
    axis equal;
    xlabel('x[\mum]');
    ylabel('y[\mum]');
    title('Differene between Different Depths After Removing Mean [\mum]');
    colorbar;
    grid on;
    subplot(2,2,2);
    zTmp = json.gridZcc*1e3;
    p = polyfit(zTmp,m,1);
    plot(zTmp,m-p(2),'o',zTmp,polyval(p,zTmp)-p(2),'--');
    xlabel('Relative Focus Position Depth [\mum]');
    ylabel('Mean Difference Between Calibrations [\mum]');
    legend('Data',sprintf('=%.3f\\cdotz',p(1)),'Location','South')
    grid on;
    axis ij
    
    pause(0.1);
    subplot(2,2,[3 4]);
    %% Compute a side by side comparison of all 3 slides
    % Find interface to zoom on to
    mi = min(min(interfZ(:,median(yPeakIs),:)))-50; %um
    mx = max(max(interfZ(:,median(yPeakIs),:)))+50; %um
    span = round((mx-mi)/diff(z(1:2)));
    scanYs = zeros(span,length(x),length(json.octFolders));
    for sI = 1:length(json.octFolders)
        % Load slides
        octPath = awsModifyPathForCompetability([experimentPath json.octFolders{sI} '/']);
        [scanY,dim] = yOCTFromTif([octPath 'scanAbs.tif'],'yI',median(yPeakIs));
        
        [~,ziStart] = min(abs(dim.z.values-mi));
        scanYs(:,:,sI) = scanY(ziStart+(0:(span-1)),:);
    end
    
    imagesc([],linspace(mi,mx,span),reshape(scanYs,span,[]))
    ylabel('OCT Scan Z Depth [\mum]');
    grid on;
    set(gca,'Color','none','XColor','none');
    title('Images Aquired at Different Focal Position');

    %% Save figure
    
    saveas(f,'interfaceZPositions_CompareToEachother.png');
    awsCopyFileFolder('interfaceZPositions_CompareToEachother.png',experimentPath);
end