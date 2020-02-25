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
if ~isempty(QA)
    
    if isfield(QA,'OCTImageQuality')
        answer1 = QA.OCTImageQuality;
    end
    
    if isfield(QA,'HandEImageQuality')
        answer2 = QA.HandEImageQuality;
    end
    
    if isfield(QA,'AlignmentQuality')
        answer3 = QA.AlignmentQuality;
    end
end

%% Ask Questions
dlgTitle1 = 'OCT Image';
in1 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    'Is Epithelium Visible? (Yes/No)' 'Yes'; ...
    'Is Most Of Image Shadowed? (Yes/No)' 'No'; ...
    'Any Notes?' ''; ...
    };
answer1 = askQuestions(in1,dlgTitle1,answer1);
if isempty(answer1)
    return;
end

dlgTitle2 = 'Histology Image';
in2 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    'Are There Visible Cell Clusters In Dermis? (Yes/No)' 'No'; ...
    sprintf('Was Gel Detached From Tissue?\nEyeball, Precentages Reflect OCT/Histology Overlap Area.\n(0%% - Not at all, 50%% - Half of interface was detached, 100%% - All of it)') '0%'; ...
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
    'Are Features In Tissue Identifying Alignment As Unique? (Yes/No. For example if tissue is very flat with no unique features mark as no)' 'Yes'; ...
    'Any Notes?' ''; ...
    };
answer3 = askQuestions(in3,dlgTitle3,answer3);
if isempty(answer3)
    return;
end
%% Process Answers
QA.OCTImageQuality = processAnsers(in1(:,1),answer1);
QA.HandEImageQuality = processAnsers(in2(:,1),answer2);
QA.AlignmentQuality = processAnsers(in3(:,1),answer3);

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
                    in{i,2} = sprintf('%f',defaultAnswers.(q));
                else
                    in{i,2} = defaultAnswers.(q);
                end
       end
    end
end

% Present dialog
dims = [1 50];
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
elseif ~isempty(str2double(a))
    a = str2double(a);
    answerType = 'double';
elseif contains(lower(q),'notes')
    %Do nothing
    answerType = 'string';
else
    error('Unknown parsed anser: %s',a);
end