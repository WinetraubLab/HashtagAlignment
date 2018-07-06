%This script checks how streight lines are

close all;
clear

%% Inputs

%Load lines flourecence image
imfp = '\\171.65.17.174\MATLAB_Share\Itamar\2018_06_13_14-59-16\Experiment.lif_Image018_ch01.tif';
im = fliplr(flipud(double(imread(imfp))));
imSize = 1.2e-3; %[m] Image size

lnNames=  { '1' '2' '3' '4' '5'}; %Line names

%% Mark Lines
pixSize = imSize/size(im,1);
[ptsPixPosition, ptsId] = findLines (im,lnNames);

%% See Streight Lines are
residuals = cell(size(lnNames));
figure(623);
ltxt = 'legend(';
for i=1:length(lnNames)
    x = ptsPixPosition(ptsId==i,1);
    z = ptsPixPosition(ptsId==i,2);
    
    zLin = polyval(polyfit(x,z,1),x);
    residuals{i} = zLin-z;
    
    
    plot((0:(length(z)-1))*pixSize*1e6,(zLin-z)*pixSize*1e6);
    if (i==1)
        hold on;
    end
    xlabel('Depth [\mum]');
    ylabel('Residual [\mum]');
    
    ltxt = sprintf('%s''%s Residual: %.1f[\\mum]'',',ltxt,lnNames{i},std(residuals{i})*pixSize*1e6);
end
hold off;
grid on;
ltxt = sprintf('%s''location'',''south'');',ltxt);
eval(ltxt);
    
