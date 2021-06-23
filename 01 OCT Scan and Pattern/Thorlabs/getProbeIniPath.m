function p = getProbeIniPath(magnificationStr)
%Returns probe ini absulte path for usage by this function

%% Input checks
if ~exist('magnificationStr','var') || isempty(magnificationStr)
	magnificationStr = '10x';
end

%% Set name 
switch(magnificationStr)
	case '10x'
		probeName = 'Probe - Olympus 10x.ini';
	case '40x'
		probeName = 'Probe - Olympus 40x.ini';
end

%% Path
currentFileFolder = [fileparts(mfilename('fullpath')) '\'];
p = awsModifyPathForCompetability(...
    [currentFileFolder '\' probeName]);