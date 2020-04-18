function updateSlideInS3(octIm,histologyIm,octOutputPath,histologyOutputPath, ...
    logImageOut, octMetadata, planeDistanceFromOrigin_mm,linesIm)
% Lines Im if exists

% Find which plane to save
d_um = planeDistanceFromOrigin_mm*1e3 - octMetadata.y.values;
yI = find (abs(d_um) == min(abs(d_um)),1,'first');
octMetadata.y.values = octMetadata.y.values(yI);
octMetadata.y.index = octMetadata.y.index(yI);

% Write OCT - cancel this part, its done in the post processing
%yOCT2Tif(octIm, octOutputPath, 'metadata', octMetadata);

% Write Histology - cancel this part, its done in the post processing
%imwrite(histologyIm,'tmp.tif');
%awsCopyFileFolder('tmp.tif',histologyOutputPath);
%delete tmp.tif;

%% Make Log Image
x = octMetadata.x.values/1e3; % mm
z = octMetadata.z.values/1e3; % mm
fig1 = figure(1);
set(fig1,'units','normalized','outerposition',[0 0 1 1]);

subplot(2,2,1);
imagesc(x,z,octIm);
xlabel('x[mm]');
ylabel('z[mm]');
colormap gray;
axis equal;
axis ij;
grid on;
title('OCT');

subplot(2,2,2);
image('XData',x,'YData',z,'CData',histologyIm);
xlabel('x[mm]');
ylabel('z[mm]');
axis equal;
axis ij;
grid on;
title('Histology');

subplot(2,2,3);
imagesc(x,z,octIm);
colormap gray;
hold on;
image('XData',x,'YData',z,...
      'CData',histologyIm,...
      'AlphaData',0.5);
hold off;
xlabel('x[mm]');
ylabel('z[mm]');
colormap gray;
axis equal;
axis ij;
grid on;
title('Combined');

if exist('linesIm','var')
    subplot(2,2,4);
    image('XData',x,'YData',z,...
          'CData',linesIm);
    hold off;
    xlabel('x[mm]');
    ylabel('z[mm]');
    colormap gray;
    axis equal;
    axis ij;
    grid on;
    title('Lines');
end

% Save
saveas(fig1,'tmp.png');
awsCopyFileFolder('tmp.png',logImageOut);
delete tmp.png
