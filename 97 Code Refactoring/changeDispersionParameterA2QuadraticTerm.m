function changeDispersionParameterA2QuadraticTerm(subjectPath)
% This function recomputes stack alignment 
% Written at Feb 27, 2020.
%%

volumesPath = [subjectPath '/OCTVolumes/'];

%% ScanConfig
pt = [volumesPath 'ScanConfig.json'];
j = awsReadJSON(pt);
j.volume.octProbe = changeField(j.volume.octProbe);
j.overview.octProbe = changeField(j.overview.octProbe);
awsWriteJSON(j,pt);

%% Overview/ScanInfo
pt = [volumesPath 'Overview/ScanInfo.json'];
j = awsReadJSON(pt);
j.octProbe = changeField(j.octProbe);
awsWriteJSON(j,pt);

%% Vloume/ScanInfo
pt = [volumesPath 'Volume/ScanInfo.json'];
j = awsReadJSON(pt);
j.octProbe = changeField(j.octProbe);
awsWriteJSON(j,pt);

end
function c=changeField(c)
if ~isfield(c,'DefaultDispersionParameterA')
    return;
end
c.DefaultDispersionQuadraticTerm = c.DefaultDispersionParameterA;
c = rmfield(c,'DefaultDispersionParameterA');
end