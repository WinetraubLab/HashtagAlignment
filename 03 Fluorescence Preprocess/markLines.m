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

% Last Modified by GUIDE v2.5 21-Aug-2019 23:44:12

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
[x,y] = ginput(2);
handles.json =AddPhotobleachedLineToJson(handles.json,x,y,'1');

drawStatus(handles)
guidata(hObject, handles);

% --- Executes on button press in pushbuttonAddGroup2Lines.
function pushbuttonAddGroup2Lines_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonAddGroup2Lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[x,y] = ginput(2);
handles.json =AddPhotobleachedLineToJson(handles.json,x,y,'2');

drawStatus(handles)
guidata(hObject, handles);


% --- Executes on button press in pushbuttonMarkTissueInterface.
function pushbuttonMarkTissueInterface_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonMarkTissueInterface (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[x,y] = ginput(2);
handles.json.FM.tissueInterface.u_pix = x(:)';
handles.json.FM.tissueInterface.v_pix = y(:)';

drawStatus(handles)
guidata(hObject, handles);


function editFileToLoad_Callback(hObject, eventdata, handles)
% hObject    handle to editFileToLoad (see GCBO)
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
handles.filePath = awsModifyPathForCompetability(get(handles.editFileToLoad,'String'));

%Find JSON in the filepath, load it and load flourescent image
folder = [fileparts(handles.filePath) '/'];
ds = fileDatastore(folder,'ReadFcn',@awsReadJSON,'FileExtensions','.json');
handles.jsonFilePath = ds.Files{1};
handles.json = ds.read();
ds = fileDatastore(awsModifyPathForCompetability([folder handles.json.photobleachedLinesImagePath]),'ReadFcn',@imread);
handles.im = ds.read();
drawStatus(handles);
guidata(hObject, handles);


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles.json.FM,'tissueInterface')
    error('Please mark tissue interface');
end
%Save JSON
hObject.Enable = 'off';
try
    awsWriteJSON(handles.json,handles.jsonFilePath);
    slideFilepath_ = handles.jsonFilePath;
    computeAlignment;
    hObject.Enable = 'on';
catch ME
    hObject.Enable = 'on';
    error(ME.message);
end

% --- Executes on button press in pushbuttonDeleteAll.
function pushbuttonDeleteAll_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonDeleteAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.json = RemoveLastPhotobleachedLine(handles.json);
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
json = handles.json;
if isfield(json.FM,'photobleachedLines')
    for i=1:length(json.FM.photobleachedLines)
        ln = json.FM.photobleachedLines(i);
        switch(ln.group)
            case {'1','v'}
                spec = '-ob';
            case {'2','h'}
                spec = '-or';
        end
        
        plot(ln.u_pix,ln.v_pix,spec,'LineWidth',2); 
    end
end

if isfield(json.FM,'tissueInterface')
    plot(json.FM.tissueInterface.u_pix,json.FM.tissueInterface.v_pix,'--ow','LineWidth',2);
end
hold off;

function json = AddPhotobleachedLineToJson(json,x,y,group)

pl.u_pix = x(:)';
pl.v_pix = y(:)';
pl.group = group;
pl.linePosition_mm = NaN;

if ~isfield(json.FM,'photobleachedLines')
    json.FM.photobleachedLines = pl;
else
    json.FM.photobleachedLines(end+1) = pl;
end

function json = RemoveLastPhotobleachedLine(json)

if ~isfield(json.FM,'photobleachedLines')
    %Do Nothing
else
    json.FM.photobleachedLines(end) = [];
    if isempty(json.FM.photobleachedLines)
        json.FM = rmfield(json.FM,'photobleachedLines');
    end
end


    