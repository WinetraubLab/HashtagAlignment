function QA = getImagePairVisualQalityMetric()
% This function will prompt user to answer a few questions about image pair
% quality matric.

QA = [];

%% Ask Questions
dlgTitle1 = 'OCT Image';
in1 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    'Is Epithelium Visible? (Yes/No)' 'Yes'; ...
    'Is Most Of Image Shadowed? (Yes/No)' 'No'; ...
    'Any Notes?' ''; ...
    };
answer1 = askQuestions(in1,dlgTitle1);
if isempty(answer1)
    return;
end

dlgTitle2 = 'Histology Image';
in2 = {... Question, default answer
    'Is Overall Image Quality Good? (Yes/No)' 'Yes'; ...
    'Is There Visible Cell Cluster In Dermis? (Yes/No)' 'No'; ...
    sprintf('Was Gel Detached From Tissue?\nEyeball, Precentages Reflect OCT/Histology Overlap Area.\n(0%% - Not at all, 50%% - Half of interface was detached, 100%% - All of it)') '0%'; ...
    'Was Tissue Folded? (Yes/No)' 'No';
    'Any Notes?' ''; ...
    };
answer2 = askQuestions(in2,dlgTitle2);
if isempty(answer2)
    return;
end

dlgTitle3 = 'Alignment';
in3 = {... Question, default answer
    'Is Overall Alignment Good? (Yes/No)' 'Yes'; ...
    'Are Features In Tissue Identifying Alignment As Unique? (Yes/No. For example if tissue is very flat with no unique features mark as no)' 'Yes'; ...
    'Any Notes?' ''; ...
    };
answer3 = askQuestions(in3,dlgTitle3);
if isempty(answer3)
    return;
end
%% Process Answers
QA.OCTImageQuality = processAnsers(in1(:,1),answer1);
QA.HandEImageQuality = processAnsers(in2(:,1),answer2);
QA.AlignmentQuality = processAnsers(in3(:,1),answer3);

function answer = askQuestions(in,dlgtitle)
dims = [1 50];
answer = inputdlg(in(:,1)',dlgtitle,dims,in(:,2)');

function y = processAnsers(qs,answes)

for i=1:length(qs)
    q = qs{i};
    a = answes{i};
    a = strtrim(a);
    
    q=q(1:find(q=='?',1,'first')-1);
    q = strrep(q,' ','');
    q = strrep(q,newline,'');
    
    if (strcmpi(a,'yes'))
        a = true;
    elseif (strcmpi(a,'no'))
        a = false;
    elseif isempty(a)
        a = '';
    elseif ~isempty(str2double(a(1:(end-1)))) && a(end) == '%'
        a  =str2double(a(1:(end-1)))/100;
    elseif contains(lower(q),'notes')
        %Do nothing
    else
        error('Unknown parsed anser: %s',a);
    end
    
    y.(q) = a;
end
