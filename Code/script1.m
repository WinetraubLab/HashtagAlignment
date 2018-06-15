%This script runs Hashtag Alignment

%% Inputs

%Histology 
histologyFluorescenceFP = 'C:\Users\Itamar\Documents\Test_HashTag_Alignment\Experiment_001.lif_Image014_ch01.tif';
histologyFluorescenceIm = fliplr(flipud(double(imread(histologyFluorescenceFP))));
histologyImageFP = 'C:\Users\Itamar\Documents\Test_HashTag_Alignment\Experiment_001.lif_Image014_ch01.tif';
histologyImage = fliplr(flipud(double(imread(histologyImageFP))));

%# Alignment Markers Specifications
%                1    2    3    4    5
lnDist = 1e-6*[-50  +50  -50    0  +50]; %Line distance from origin [m]
lnDir  =      [  0    0    1    1    1]; %Line direction 0 - left right, 1 - up down
lnNames=     { '-x' '+x' '-y' '0y' '+y'}; %Line names

%OCT
OCTVolumeFolder = 'Y:\tmpData2\06072018\2018_06_07_14-48-32\';
OCTVolumePosition = [-2e-3 -2e-3    0; ... %x,y,z position [m] of the first A scan in the first B scan (1,1)
                      2e-3  2e-3  2e-3]';     %x,y,z position [m] of the las A scan in the last B scan (end,end). z is deeper!
dispersionParameterA = 2.271e-02;  %Use this dispersion Parameter for air-water interface - Wasatch

%Plotting
%plot after step #     1     2     3
isPlotStepResults = [ false true false];

%Enter your own points (optional). Comment out if not in use
%ptsPixPosition = [3.070484e+02,2.718646e+02;3.070675e+02,2.713169e+02;3.070715e+02,2.712032e+02;3.070627e+02,2.714557e+02;3.070434e+02,2.720064e+02;3.070161e+02,2.727875e+02;3.069881e+02,2.735892e+02;3.059865e+02,3.022421e+02;3.060434e+02,3.006135e+02;3.061910e+02,2.963922e+02;3.064613e+02,2.886598e+02;3.604484e+02,2.770459e+02;3.613164e+02,2.760205e+02;3.627069e+02,2.743780e+02;3.627370e+02,2.743425e+02;3.625236e+02,2.745946e+02;3.611839e+02,2.761771e+02;3.618349e+02,2.754081e+02;3.605936e+02,2.768743e+02;3.605772e+02,2.768937e+02;3.609027e+02,2.765092e+02;3.626871e+02,2.744014e+02;2.269774e+02,2.562015e+02;2.271478e+02,2.645088e+02;2.273061e+02,2.722273e+02;2.274495e+02,2.792209e+02;2.275753e+02,2.853539e+02;2.276806e+02,2.904903e+02;2.277628e+02,2.944943e+02;2.278189e+02,2.972298e+02;2.278462e+02,2.985611e+02;2.278419e+02,2.983522e+02;2.278032e+02,2.964673e+02;1.986935e+02,2.839746e+02;1.987462e+02,2.803890e+02;1.987803e+02,2.780689e+02;1.987957e+02,2.770143e+02;1.987926e+02,2.772252e+02;1.987710e+02,2.787016e+02;1.987307e+02,2.814436e+02;1.986719e+02,2.854510e+02;1.985945e+02,2.907240e+02;1.984985e+02,2.972625e+02;1.983839e+02,3.050665e+02;1.692742e+02,2.884973e+02;1.703313e+02,2.860670e+02;1.703345e+02,2.860597e+02;1.702949e+02,2.861506e+02;1.702238e+02,2.863141e+02;1.701323e+02,2.865246e+02;1.700314e+02,2.867564e+02;1.699324e+02,2.869840e+02;1.698464e+02,2.871817e+02;1.697846e+02,2.873239e+02;1.697581e+02,2.873848e+02]; %(pixX,pixY)
%ptsId = [1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5];
                  
%% Step #1: Find Feducial Marker in Fluorescence Image: ptsPixPosition, ptsId
if (~exist('ptsPixPosition','var'))
    %TBD, merge with Itamar
    [ptsPixPosition, ptsId] = findLines (histologyFluorescenceIm,lnNames);
    
    %Output points, in case we would want to use them
    s1 = sprintf('%d,%d;',ptsPixPosition');
    s2 = sprintf('%d,',ptsId);
    fprintf('ptsPixPosition = [%s]; %%(pixX,pixY)\n',s1(1:(end-1)));
    fprintf('ptsId = [%s];\n',s2(1:(end-1)));
end

%% Step #2: Find Plane Parameters: u,v,h

%Find position and direction by line identity
ptsLnDist = lnDist(ptsId); ptsLnDist = ptsLnDist(:);
ptsLnDir  = lnDir(ptsId);  ptsLnDir  = ptsLnDir(:);

%Compute plane parameters
[u,v,h] = identifiedPointsToUVH (ptsPixPosition,ptsLnDist, ptsLnDir);

%Find intercepts
%   h+U*u+V*v=(?;0).
%   U=-(h(2)+V*v(2))/u(1)
V = mean(ptsPixPosition(:,2)); %Take average image height
UX=-(h(2)+V*v(2))/u(2);
X=u(1)*UX+v(2)*V+h(1);
UY=-(h(1)+V*v(1))/u(1);
Y=u(2)*UY+v(2)*V+h(2);

if isPlotStepResults(2)
    
    fprintf('Pixel Size: |u|=%.3f[microns], |v|=%.3f[microns]\n',norm(u)*1e6,norm(v)*1e6)
    fprintf('Angle In X-Y Plane: %.2f[deg], Tilt: %.2f[deg]\n',atan2(u(2),u(1))*180/pi,acos(dot(v/norm(v),[0;0;1]))*180/pi);
    fprintf('Intercept Points. x=%.3f[mm],y=%.3f[mm]\n',1e3*X,1e3*Y);

    %Plot
    figure(2);
    
    %Main Figure
    imagesc(histologyFluorescenceIm);
    hold on;
    
    %Plot points found on figure
    ltxt = 'legend(';
    for i=1:length(lnNames)
        %Plot all the idetified points used in calculation
        if (sum(ptsId==i)>0) %Are there any points in that line
            ltxt = sprintf('%s''%s'',',ltxt,lnNames{i});
            plot(ptsPixPosition(ptsId==i,1),ptsPixPosition(ptsId==i,2),'.');
        end
    end
    ltxt = sprintf('%s''location'',''south'');',ltxt);
    
    %Plot Intercepts
    sx = size(histologyFluorescenceIm,2);
    sz = size(histologyFluorescenceIm,1);
    plot(UX*[1 1],[1 sx],'--r',UY*[1 1],[1 sx],'--r');
    text(UX,sz/4,sprintf('X Intercept\n%.3f[mm]',X*1e3),'Color','red')
    text(UY,sz/4,sprintf('Y Intercept\n%.3f[mm]',Y*1e3),'Color','red')
    
    hold off;
    colormap gray;
    eval(ltxt);
    title('Step #2: Plane Paramaters');
    pause(0.01);
    
end

%% Step #3: Reslice OCT Volume to Find B-Scan That Fits Histology
if ~exist(OCTVolumeFolder,'dir')
    return; %No OCT to Slice, we are done
end

%Reslice
rOCT = resliceOCTVolume( ...
    u,v,h,size(histologyImage), ...
    OCTVolumeFolder,OCTVolumePosition,'Wasatch',dispersionParameterA ...
    );

%% Plot
figure(3);
imagesc(log(rOCT));
colormap gray;
title('OCT Slice');
pause(0.01);

return;
%% This code is experimental, may be removed in the future.
%Load Intef From file
[interf,dimensions] = yOCTLoadInterfFromFile(OCTVolumeFolder,'OCTSystem','Wasatch');

%Generate BScans
scanCpx = yOCTInterfToScanCpx(interf,dimensions ...
    ,'dispersionParameterA', dispersionParameterA ...Use this dispersion Parameter for air-water interface
    );

%Average B Scan Averages
scanAbs = mean(abs(scanCpx),4);

%Re-arange dimensions such that scanAbs is (x,y,z)
scanAbs = shiftdim(scanAbs,1);

%Reslice
rOCT = resliceOCTVolume(scanAbs, OCTVolumePosition,u,v,h,size(histologyImage));

%TBD find h(z)

%TBD plot


