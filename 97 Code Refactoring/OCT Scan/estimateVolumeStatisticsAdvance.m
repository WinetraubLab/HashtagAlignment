function estimateVolumeStatisticsAdvance(subjectPath)
% This function advances estimateDepthOfPenetration. Writen for LG.
% Written at July 18, 2020.

if ~exist('subjectPath','var')
    subjectPath = s3SubjectPath('02','LG');
end

OCTVolumesFolder_ = [subjectPath '\OCTVolumes\'];
estimateDepthOfPenetration