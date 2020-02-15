function [pmIM, alpha] = generateOverlayPhotobleachedLineOnOCT(json, y_um)
%Draw photobleach lines image to be overlayed ontop of OCT

%Onvert OCT image grid to original image
[xx_um,zz_um] = meshgrid(...
    json.sectionIterationConfig.data_um.x.values, ...
    json.sectionIterationConfig.data_um.z.values);
pmIM1 = zeros(size(xx_um));

xyz1 = json.sectionIterationConfig.data.new2OriginalAffineTransform * ...
    [xx_um(:)'; y_um*ones(1,numel(xx_um)); zz_um(:)'; ones(1,numel(xx_um))];

vLines = json.scanConfig.data.photobleach.vLinePositions;
hLines = json.scanConfig.data.photobleach.hLinePositions;
for i=1:length(vLines)
    ii = abs(xyz1(1,:)-vLines(i)*1e3)<3;
    pmIM1(ii) = 1;
end
for i=1:length(hLines)
    ii = abs(xyz1(2,:)-hLines(i)*1e3)<3;
    pmIM1(ii) = pmIM1(ii) + 2;
end
    
pmIMR = zeros(size(pmIM1),'uint8');
pmIMG = pmIMR;
pmIMB = pmIMR;

pmIMR(pmIM1==1 | pmIM1==3) = 255;
pmIMB(pmIM1==2 | pmIM1==3) = 256;
pmIM = zeros([size(pmIMR) 3],'uint8');
pmIM(:,:,1) = pmIMR;
pmIM(:,:,2) = pmIMG;
pmIM(:,:,3) = pmIMB;
alpha = double(pmIM1 ~= 0);
%imshow(pmI);
