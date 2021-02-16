function QA = getImagePairVisualQualityMetric(QA)
% This function will prompt user to answer a few questions about image pair
% quality matric.
% QA - default or current QA metric

if ~exist('QA','var')
    QA = [];
end

% set default answers if exist
answer1 = []; 
answer2 = [];
answer3 = [];
answer4 = [];
if ~isempty(QA)
    
    if isfield(QA,'OCTImageQuality')
        answer1 = QA.OCTImageQuality;
    end
    
    if isfield(QA,'HandEImageQuality_InOverlapArea')
        answer2 = QA.HandEImageQuality_InOverlapArea;
    end
    
    if isfield(QA,'AlignmentQuality')
        answer3 = QA.AlignmentQuality;
    end
    
    if isfield(QA,'VisibleObjectsInBothImages')
        answer4 = QA.VisibleObjectsInBothImages;
    end
end

%% Ask Questions
dlgTitle1 = 'OCT Image';
in1 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    'Is Epithelium Visible? (Yes/No)' 'Yes'; ...
    'Is Dermis Visible? (Yes/No) If Dermis is only slightly visible, mark as no.' 'Yes'; ...
    'Is Most Of Image Shadowed? (Yes/No)' 'No'; ...
    'Any Notes?' ''; ...
    };
answer1 = askQuestions(in1,dlgTitle1,answer1);
if isempty(answer1)
    return;
end

dlgTitle2 = 'Histology Image - Only the Part that Overlaps with OCT';
in2 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    sprintf('Was Gel Detached From Tissue?\n(Eyeball 0%% - Not at all, 50%% - Half of interface was detached, 100%% - All of it)') '0%'; ...
    sprintf('Tissue Breakage Or Holes Present?\n(Eyeball 0%% - Not at all, 25%% - small holes here and there, 50%% - some big holes , 100%% - All of it)') '0%'; ...
    'Was Tissue Folded? (Yes/No)' 'No';
    'Any Notes?' ''; ...
    };
answer2 = askQuestions(in2,dlgTitle2,answer2);
if isempty(answer2)
    return;
end

dlgTitle3 = 'Alignment';
in3 = {... Question, default answer
    'Overall Alignment Quality? (3 - Almost Perfect, 2 - Fair, 1 - Poor)' '3'; ...
    sprintf('Y Axis Tolerance Microns?\n(How many microns can you transvers along Y axis on each side from best alignments and features still match between OCT and histology, capped by 100 microns).\nExample: if you can go +-25um from best alignment, write: 25') '20'; ...
    'Was Surface Used To Align? (Yes/No)' 'Yes'; ...
    'Were Features Inside Tissue Used In Alignment? (Yes/No)' 'Yes'; ...
    'Any Notes?' ''; ...
    };
answer3 = askQuestions(in3,dlgTitle3,answer3);
if isempty(answer3)
    return;
end

dlgTitle4 = 'Objects Visible In Both OCT and Histology';
in4 = {... Question, default answer
    'Hair Follicles? (Yes/No, can be seen in both OCT and histology)' 'No'; ...
    'Clusters Of Cells Inside Dermis? (Yes/No, can be seen in both OCT and histology)' 'No'; ...
    'Clumps In Gel? (Yes/No, can be seen in both OCT and histology)' 'No'; ...
    'Any Notes?' ''; ...
    };
answer4 = askQuestions(in4,dlgTitle4,answer4);
if isempty(answer4)
    return;
end
%% Process Answers
QA = [];
QA.OCTImageQuality = processAnsers(in1(:,1),answer1);
QA.HandEImageQuality_InOverlapArea = processAnsers(in2(:,1),answer2);
QA.AlignmentQuality = processAnsers(in3(:,1),answer3);
QA.VisibleObjectsInBothImages = processAnsers(in4(:,1),answer4);


%% Check for errors
if (QA.AlignmentQuality.YAxisToleranceMicrons < 5)
    error('OCT spot size is a few microns, its very unlikely that the Y Axis Tolerance Microns is so low');
end

function answer = askQuestions(in,dlgtitle,defaultAnswers)

% Build default answers
for i=1:size(in,1)
    q = question2varible(in{i,1});
    if isfield(defaultAnswers,q)
       [~,answerType] = extractAnswer(in{i,2},in{i,1});
       switch(answerType)
           case 'bool'
               if defaultAnswers.(q)==1
                   in{i,2} = 'Yes';
               else
                   in{i,2} = 'No';
               end
           case 'percent'
               in{i,2} = sprintf('%.0f%%',defaultAnswers.(q)*100);
           otherwise
                if isnumeric(defaultAnswers.(q))
                    in{i,2} = sprintf('%.1f',defaultAnswers.(q));
                else
                    in{i,2} = defaultAnswers.(q);
                end
       end
    end
end

% Present dialog
dims = [1 80];
answer = inputdlg(in(:,1)',dlgtitle,dims,in(:,2)');

function y = processAnsers(qs,answes)

for i=1:length(qs)
    q = qs{i};
    a = answes{i};
    a = strtrim(a);
    q = question2varible(q);
    a = extractAnswer(a,q);
    
    y.(q) = a;
end

function q = question2varible(q)
q=q(1:find(q=='?',1,'first')-1);
q = strrep(q,' ','');
q = strrep(q,newline,'');

function [a,answerType] = extractAnswer(a,q)

if (strcmpi(a,'yes'))
    a = true;
    answerType = 'bool';
elseif (strcmpi(a,'no'))
    a = false;
    answerType = 'bool';
elseif isempty(a)
    a = '';
    answerType = 'string';
elseif ~isempty(str2double(a(1:(end-1)))) && a(end) == '%'
    a  = str2double(a(1:(end-1)))/100;
    answerType = 'percent';
elseif ~isempty(str2double(a)) && ~isnan(str2double(a))
    a = str2double(a);
    answerType = 'double';
elseif contains(lower(q),'notes')
    %Do nothing
    answerType = 'string';
else
    error('Unknown parsed anser: %s',a);
end