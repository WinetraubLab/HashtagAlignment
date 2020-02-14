function dat = octFromTifCash(filePath, yI)
%This fuction returns an OCT plane but reads it slowly from cash

persistent gFilePath;
persistent gCashData;

%% Make sure cash is up to date
if isempty(gFilePath) || ~strcmp(filePath,gFilePath)
    % Time to clear cash
    gCashData = {};
    gFilePath = filePath;
end

%% Is index exist
if (yI <= 0)
    dat = [];
    return;
end

%% Is this index in cash?
if (yI <= length(gCashData) && ~isempty(gCashData{yI}))
    % Cashed, do nothing
else
    %Index not cashed, load it
    gCashData{yI} = yOCTFromTif(filePath,'yI',yI);
end

dat = gCashData{yI}; % This data is cashed

    