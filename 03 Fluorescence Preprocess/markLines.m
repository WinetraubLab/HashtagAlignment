function varargout = markLines(varargin)
% MARKLINES MATLAB code for markLines.fig
%      MARKLINES, by itself, creates a new MARKLINES or raises the existing
%      singleton*.
%
%      H = MARKLINES returns the handle to a new MARKLINES or the handle to
%      the existing singleton*.
%
%      MARKLINES('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARKLINES.M with the given input arguments.
%
%      MARKLINES('Property','Value',...) creates a new MARKLINES or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before markLines_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to markLines_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help markLines

% Last Modified by GUIDE v2.5 06-Sep-2019 16:57:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @markLines_OpeningFcn, ...
                   'gui_OutputFcn',  @markLines_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before markLines is made visible.
function markLines_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to markLines (see VARARGIN)

% Choose default command line output for markLines
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes markLines wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = markLines_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbuttonAddGroup1Lines.
function pushbuttonAddGroup1Lines_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonAddGroup1Lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[x,y] = getline();
handles.slideJson = AddFiducialLineToJson(handles.slideJson,x([1 end]),y([1 end]),'1');

drawStatus(handles)
guidata(hObject, handles);

% --- Executes on button press in pushbuttonAddGroup2Lines.
function pushbuttonAddGroup2Lines_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonAddGroup2Lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[x,y] = getline();
handles.slideJson = AddFiducialLineToJson(handles.slideJson,x([1 end]),y([1 end]),'2');

drawStatus(handles)
guidata(hObject, handles);


% --- Executes on button press in pushbuttonMarkTissueInterface.
function pushbuttonMarkTissueInterface_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonMarkTissueInterface (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[x,y] = getline();
handles.slideJson = AddFiducialLineToJson(handles.slideJson,x([1 end]),y([1 end]),'t'); 

drawStatus(handles)
guidata(hObject, handles);


function editFileToLoad_Callback(hObject, eventdata, handles)
% hObject    handle to 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function editFileToLoad_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editFileToLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function axes1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
axis off;
currentFileFolder = fileparts(mfilename('fullpath'));
yOCTMainFolder = [currentFileFolder '\..\'];
d = dir(yOCTMainFolder);yOCTMainFolder = [d(1).folder '\'];

p=path;
if ~contains(p,yOCTMainFolder)
    addpath(genpath(yOCTMainFolder)); %Add current files to path
end
awsSetCredentials(1);

% --- Executes on button press in pushbuttonLoad.
function pushbuttonLoad_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%handles.
guidata(hObject, handles);
if isempty(handles)
    return;
end
filePath = get(handles.editFileToLoad,'String');
if(filePath(end) ~= '/')
    filePath(end+1) = '/';
end
filePath = awsModifyPathForCompetability(filePath);

hObject.Enable = 'off';
pause(0.01);
try
    awsSetCredentials();
    
    %Find Slide JSON in the filepath, load it and load flourescent image
    folder = [fileparts(filePath) '/'];
    ds = fileDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
    handles.slideJsonFilePath = ds.Files{1};
    handles.slideJson = ds.read();
    ds = fileDatastore(awsModifyPathForCompetability([folder handles.slideJson.photobleachedLinesImagePath]),'ReadFcn',@imread);
    handles.im = ds.read();
    
    handles.allSlidesPath = awsModifyPathForCompetability([fileparts(handles.slideJsonFilePath) '/../']);
    
    %Load Stack
    ds = fileDatastore(handles.allSlidesPath,'ReadFcn',@awsReadJSON,'FileExtensions','.json','IncludeSubfolders',true);
    slideJsonStack = ds.readall;
    xx = cellfun(@(x)(isequaln(handles.slideJson,x)),slideJsonStack);
    if sum(xx) ~= 1
        disp('Couldn''t locate position in stack');
    end
    handles.slideJsonPositionInStack = find(xx,1,'first');
    handles.slideJsonStack = [slideJsonStack{:}];
    
    %Load Oct Volume JSON
    folder = awsModifyPathForCompetability([handles.allSlidesPath '/../OCTVolumes/']);
    ds = fileDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
    handles.octVolumeJsonFilePath = ds.Files{1};
    handles.octVolumeJson = ds.read();
    
    handles.isIdentifySuccssful = false;

    drawStatus(handles);
    guidata(hObject, handles);

    hObject.Enable = 'on';
catch ME
    hObject.Enable = 'on';
    rethrow(ME);
end

%Save button pressed
function pushbutton6_Callback(hObject, eventdata, handles)

err = ~isfield(handles.slideJson.FM,'fiducialLines');
if ~err
    gr = [handles.slideJson.FM.fiducialLines.group];
    if ~contains(gr,'t')
        err = true;
    end
end

if err
    error('Please mark group 1 lines, group 2 lines and tissue interface');
end

%Save JSON
hObject.Enable = 'off';
try
    awsSetCredentials(1);
    awsWriteJSON(handles.slideJson,handles.slideJsonFilePath);
    
    %Upload the PNG if successful
    pngPath = awsModifyPathForCompetability([fileparts(handles.slideJsonFilePath) '/SlideAlignment.png']);
    if (handles.isIdentifySuccssful && exist('SlideAlignment.png','file'))
        if (awsIsAWSPath(pngPath))
            %Upload to AWS
            awsCopyFileFolder('SlideAlignment.png',pngPath);
        else
            copyfile('SlideAlignment.png',pngPath);
        end   
    end
    hObject.Enable = 'on';
catch ME
    hObject.Enable = 'on';
    rethrow(ME);
end

% Delete Line button pressed
function pushbuttonDeleteAll_Callback(hObject, eventdata, handles)

[u0,v0] = getline();

handles.slideJson = RemoveFiducialLineClosestTo(handles.slideJson,mean(u0),mean(v0));
drawStatus(handles)
guidata(hObject, handles);

function drawStatus(handles)

L = get(gca,{'xlim','ylim'});  % Get axes limits.
imagesc(handles.im);
axis equal;
axis off;
colormap gray;

if (sum(L{1} == [0 1]) + sum(L{2} == [0 1]) == 4)
    %This is the first time the figure appears. No zoom to return to
else
    zoom reset
    set(gca,{'xlim','ylim'},L)
end

hold on;
FM = handles.slideJson.FM;
if isfield(FM,'fiducialLines') 
    for i=1:length(FM.fiducialLines)
        ln = FM.fiducialLines(i);
        switch(ln.group)
            case {'1','v'}
                spec = '-ob';
            case {'2','h'}
                spec = '-or';
            case 't'
                spec = '--ow';
        end
        
        plot(ln.u_pix,ln.v_pix,spec,'LineWidth',2); 
    end
end
hold off;

function json = AddFiducialLineToJson(json,x,y,group)
f = fdlnCreate(x(:),y(:),group);

if ~isfield(json.FM,'fiducialLines')
    json.FM.fiducialLines = f;
else
    json.FM.fiducialLines(end+1) = f;
end

function json = RemoveFiducialLineClosestTo(json,u0,v0)

if ~isfield(json.FM,'fiducialLines') || isempty(json.FM.fiducialLines)
    %Do Nothing
else
    %Find which line is the closest to the mouse click
    fs = json.FM.fiducialLines;
    d = zeros(size(fs));
    for i=1:length(d)
        f = fs(i);
        
        u = f.u_pix([1 end]);
        v = f.v_pix([1 end]);
        
        Q1 = [u(1); v(1)];
        Q2 = [u(2); v(2)];
        P = [u0; v0];
        
        l = Q2-Q1;
        n = [l(2); -l(1)];%normal
        
        dt = dot(l,P-Q1)/norm(l);
        if (dt > 0 && dt < norm(l))
            %Intersection is closes to the line
            d(i) = abs(dot(P-Q1,n))/norm(n);
        else
            %Intersection is outside, d is the closest distance to edge
            %points
            d(i) = min(norm(P-Q1),norm(P-Q2));
        end
    end
    iLineToDelete = find(d==min(d),1,'first');
    
    json.FM.fiducialLines(iLineToDelete) = [];
end

if isempty(json.FM.fiducialLines)
    json.FM = rmfield(json.FM,'fiducialLines');
end


    


% --- Executes on button press in pushbuttonIdentifyManually.
function pushbuttonIdentifyManually_Callback(hObject, eventdata, handles)

[slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(handles.slideJson,handles.octVolumeJson,'Manual');
plotSignlePlane(slideJson.FM.singlePlaneFit,slideJson.FM.fiducialLines,handles.im,handles.octVolumeJson,isIdentifySuccssful);
if (isIdentifySuccssful)
    handles.slideJson = slideJson;
    handles.isIdentifySuccssful = true;
end
guidata(hObject, handles);

% --- Executes on button press in pushbuttonIdentifyByRatio.
function pushbuttonIdentifyByRatio_Callback(hObject, eventdata, handles)

[slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(handles.slideJson,handles.octVolumeJson,'ByLinesRatio');
plotSignlePlane(slideJson.FM.singlePlaneFit,slideJson.FM.fiducialLines,handles.im,handles.octVolumeJson,isIdentifySuccssful);
if (isIdentifySuccssful)
    handles.slideJson = slideJson;
    handles.isIdentifySuccssful = true;
end
guidata(hObject, handles);

% --- Executes on button press in pushbuttonIdentifyByStack.
function pushbuttonIdentifyByStack_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonIdentifyByStack (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%Update this in the right place in stack
handles.slideJsonStack(handles.slideJsonPositionInStack) = handles.slideJson;

%Compute stack fit
[slideJson,isIdentifySuccssful] = identifyLinesAndAlignSlide(handles.slideJson,handles.octVolumeJson,'ByStack',handles.slideJsonStack);
if (isIdentifySuccssful)
    drawStatus(handles); %Update 
    plotSignlePlane(slideJson.FM.singlePlaneFit,slideJson.FM.fiducialLines,handles.im,handles.octVolumeJson,isIdentifySuccssful);
    handles.slideJson = slideJson;
    handles.isIdentifySuccssful = true;
end
guidata(hObject, handles);