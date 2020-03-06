function [ExpansionorShrinkagePercent,rotation_deg,xTranslation_um,zTranslation_um] = transform2Knobes (histologyToOCTT,histologyScale_umperpix,octScale_umperpix)
% histologyScale_umperpix - size of histology image pixels,
% octScale_umperpix - size of oct image pixels
% ExpansionorShrinkagePercent - expansion, - shrinkage
% histologyToOCTT = HistToMicrons -> Rotate -> Translate -> MicronsToOCT
% So we will invert them one by one

%% Invert MicronsToOCT
MicronsToOCT = [octScale_umperpix 0 0; 0 octScale_umperpix 0; 0 0 1];
Tall = histologyToOCTT * MicronsToOCT;

%% Extract Translation
xTranslation_um = Tall(3,1);
zTranslation_um = Tall(3,2);
T = [1 0 0; 0 1 0; xTranslation_um zTranslation_um 1];
Tall = Tall * T^-1; 

%% Extract Rotation
rotation_deg = atan2(Tall(1,2),Tall(2,2)) * 180/pi;
c = cos(rotation_deg*pi/180);
s = sin(rotation_deg*pi/180);
R = [c s 0; -s c 0; 0 0 1];

Tall = Tall * R^-1;
%% Extract pixel size of the new image & scale factor
pixelSize_um = mean([Tall(1,1), Tall(2,2)]);
HistToMicrons = [pixelSize_um 0 0; 0 pixelSize_um 0; 0 0 1];
Tall = Tall * HistToMicrons^-1;

ExpansionorShrinkagePercent = (histologyScale_umperpix/pixelSize_um - 1)*100;

%% Check nothing is left
if (norm(diag([1 1 1]) - Tall) > 1e-3)
    error('Transform failed');
end