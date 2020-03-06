function histologyToOCTT = knobesToTransform( ...
    scale_percent,rotation_deg,xTranslation_um,zTranslation_um, histologyScale_umperpix, octScale_umperpix)
% For explanation about the tranformation see website:
% scale_percent  - negative is shrinkage
% histologyScale_umperpix - size of histology image scanned,
% octScale_umperpix - size of OCT image.
% https://www.mathworks.com/help/images/matrix-representation-of-geometric-transformations.html

%% Scale
scale_umperpix = histologyScale_umperpix/(scale_percent/100+1);
HistToMicrons = [scale_umperpix 0 0; 0 scale_umperpix 0; 0 0 1];

%% Rotate
c = cos(rotation_deg*pi/180);
s = sin(rotation_deg*pi/180);

R = [c s 0; -s c 0; 0 0 1];

%% Translate
T = [1 0 0; 0 1 0; xTranslation_um zTranslation_um 1];

%% Scale to OCT
MicronsToOCT = [1/octScale_umperpix 0 0; 0 1/octScale_umperpix 0; 0 0 1];

%% Overall transformation
% Notice that the oder of operations is flipped from what we are used to,
% see tester.
% histologyToOCTT = HistToMicrons -> Rotate -> Translate -> MicronsToOCT
histologyToOCTT =  HistToMicrons * R * T * MicronsToOCT;
