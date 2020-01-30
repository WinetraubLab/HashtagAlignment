function [scale_umperpix,rotation_deg,xTranslation_um,zTranslation_um] = transform2Knobes (histologyToOCTT,octScale_umperpix)

% histologyToOCTT = HistToMicrons -> Rotate -> Translate -> MicronsToOCT
% So we will invert them one by one

%% Invert MicronsToOCT
MicronsToOCT = [octScale_umperpix 0 0; 0 octScale_umperpix 0; 0 0 1];
Tall = histologyToOCTT * MicronsToOCT^-1;

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
%% Extract scale
scale_umperpix = mean([Tall(1,1), Tall(2,2)]);
HistToMicrons = [scale_umperpix 0 0; 0 scale_umperpix 0; 0 0 1];
Tall = Tall * HistToMicrons^-1;

%% Check nothing is left
if (norm(diag([1 1 1]) - Tall) > 1e-3)
    error('Transform failed');
end