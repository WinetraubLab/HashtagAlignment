% This script computs stats for the following libraries

libraryNames = {'LG','LF','LE','LD','LC'};

%% Time dependence

if mod(round(now),7) == 0 % On the run between Thursday and Friday
    % Run over all liberies
else
    % Run on the latest libery only to save time.
    libraryNames = libraryNames(1);
end

%% Compute section status report
for i=1:length(libraryNames)
    ln = libraryNames{i};
    fprintf('%s Processing %s\n',datestr(datetime),ln);
    statsPath = [s3SubjectPath('',ln) '0LibraryStatistics/'];
    
    % Generate status
    fprintf('%s Building Stats Report\n',datestr(datetime));
    st = generateStatusReportByLibrary(ln);
    
    % Write it to AWS
    awsWriteJSON(st,[statsPath '/StatusReportBySection.json']);
    
    % Read from AWS
    % st = awsReadJSON([statsPath '/StatusReportBySection.json'])
    
    % Upload to cloud
    fprintf('%s Submitting to Google Sheets\n',datestr(datetime));
    submitStatusReportToGoogle(st);
end
fprintf('%s Done!\n',datestr(datetime));



