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
OCTVolumeFolder = '';
OCTVolumePosition = [-1e-3 -1e-3 ; ... %x,y position [m] of the first A scan in the first B scan (1,1)
                      1e-3  1e-3];     %x,y position [m] of the las A scan in the last B scan (end,end)
dispersionParameterA = 0.0058;

%Plotting
%plot after step #     1     2     3
isPlotStepResults = [ false true false];

%Enter your own points (optional). Comment out if not in use
%ptsPixPosition = [100, 100; 200, 200]; %(pixX,pixY)
%ptsId          = [1  ,      2       ];
                  
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
    
end

%% Step #3: Reslice OCT Volume to Find B-Scan That Fits Histology

%Load Intef From file
[interf,dimensions] = yOCTLoadInterfFromFile(OCTVolumeFolder,'OCTSystem','Wasatch');

%Generate BScans
scanCpx = yOCTInterfToScanCpx(interf,dimensions ...
    ,'dispersionParameterA', dispersionParameterA ...Use this dispersion Parameter for air-water interface
    );

%Average B Scan Average
scanAbs = mean(abs(scanCpx),4);

%Re-arange dimensions such that scanAbs is (x,y,z)
scanAbs = shiftdim(scanAbs,1);

%TBD reslice

%TBD find h(z)

%TBD plot


