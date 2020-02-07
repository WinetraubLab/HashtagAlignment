function subjectName = s3GetSubjectName(subjectPath)

s = awsModifyPathForCompetability([subjectPath '/']);
[~,subjectName] = fileparts([s(1:(end-1)) '.a']);
