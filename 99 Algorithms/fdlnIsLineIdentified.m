function isIt = fdlnIsLineIdentified (fdln)
%Are lines in fdln structure identified? meaning are they of type
%'v','h', or 't' and at least one 'h' and one 'v'
%INPUT:
%   fdln - a single Fiducial Line structure or an array of a few
%       structures
%OUPTUT:
%   isIt - 0 if non of fdln are identified, 1 - if all are identified, 0.5
%   if some but not all are identified

gr = lower([fdln.group]);
is = gr=='v' | gr=='h' | gr=='t';
is = sum(is);

isContains = (sum(gr=='v')>=2) + (sum(gr=='h')>=2);

if (is == 0)
    isIt = 0;
elseif (is == length(gr))
    if (isContains == 2)
        isIt = 1;
    else
        isIt = 0.5; %Doesn't contain all required lines
    end
else
    isIt = 0.5;
end