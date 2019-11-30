function p = getProbeIniPath()
%Returns probe ini absulte path for usage by this function

currentFileFolder = [fileparts(mfilename('fullpath')) '\'];
p = awsModifyPathForCompetability(...
    [currentFileFolder '\Probe - Olympus 10x.ini']);