function varargout = Line_Recognition(varargin)
% LINE_RECOGNITION MATLAB code for Line_Recognition.fig
%      LINE_RECOGNITION, by itself, creates a new LINE_RECOGNITION or raises the existing
%      singleton*.
%
%      H = LINE_RECOGNITION returns the handle to a new LINE_RECOGNITION or the handle to
%      the existing singleton*.
%
%      LINE_RECOGNITION('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LINE_RECOGNITION.M with the given input arguments.
%
%      LINE_RECOGNITION('Property','Value',...) creates a new LINE_RECOGNITION or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Line_Recognition_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Line_Recognition_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Line_Recognition

% Last Modified by GUIDE v2.5 11-May-2018 17:29:01

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Line_Recognition_OpeningFcn, ...
                   'gui_OutputFcn',  @Line_Recognition_OutputFcn, ...
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


% --- Executes just before Line_Recognition is made visible.
function Line_Recognition_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Line_Recognition (see VARARGIN)

% Choose default command line output for Line_Recognition
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Line_Recognition wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Line_Recognition_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename pathname] = uigetfile({'*.jpg';'*.bmp';'*.tif'},'File Selector');
a=imread([pathname filename]);
a=mat2gray(imrotate(a,180));
axes(handles.axes1);
[r,c]=size(a)
imshow(a);
xlim(handles.axes1,[0 c]);
ylim(handles.axes1,[0 r]);
set(handles.axes1,'visible','on')
guidata(hObject,a)



% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

resp= 'Y';
j=0;
t=1;
while 1
    if strcmpi(resp,'N')
        break;
    end
[xi,yi] = getline;
hold on
plot(xi,yi,'r')
a = guidata(hObject);
j=j+1;
for i=1:1:length(xi)
   x_temp=a(round(yi(i)),(round(xi(i)))-10:(round(xi(i))+10));
   if mod(j, 2) == 0
      y_temp=heaviside([(-length(x_temp)/2):(length(x_temp)/2)]); 
   else
      y_temp=fliplr(heaviside([(-length(x_temp)/2):(length(x_temp)/2)]));
   end
   
   [acor,lag] = xcorr(x_temp,y_temp);
   [~,I] = max(abs(acor));
   lagDiff = lag(I);
   x_fix(i)= xi(i)-lagDiff+1;
end
vq_data_x=interp1([0:1:length(x_fix)-1],x_fix,[0:(length(x_fix)-1)/10:length(x_fix)-1],'spline');
vq_data_y=interp1([0:1:length(yi)-1],yi,[0:(length(yi)-1)/10:length(yi)-1],'spline');
hold on;
plot(vq_data_x,vq_data_y,'b')
Points_temp_x(:,j)=vq_data_x;
Points_temp_y(:,j)=vq_data_y;
if mod(j, 2) == 0
    x1=Points_temp_x(:,j-1);
    y1=Points_temp_y(:,j-1);
    x2=Points_temp_x(:,j);
    y2=Points_temp_y(:,j);
    x=mean([x1 x2],2);
    y=mean([y1 y2],2);
    p=polyfit(x,y,1);
    hold on;
    plot(x,p(1)*x+p(2),'g');
    if j/2==1 || j/2==3
       Points_x(:,t:t+1)=[x circshift(x,-1)];
       Points_y(:,t:t+1)=[(p(1)*x+p(2)) circshift(p(1)*x+p(2),-1)];
       t=t+2;
    else
        Points_x(:,t)=x;
        Points_y(:,t)=p(1)*x+p(2);
        t=t+1;
    end
end
resp = inputdlg('Do you wish to enter an additional value? Y/N: ','s');
clear xi; clear yi; clear x_temp; clear y_temp; clear acor; clear lag;
clear I; clear lagDiff; clear x_fix; clear vq_data_x; clear vq_data_y;
clear x1; clear x2; clear y1; clear y2; clear x; clear y;
end
guidata(hObject,[(Points_x-1) (Points_y-1)]*2.34274)




% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Points = guidata(hObject);
[r c]=size(Points)
Points_x = Points(:,1:c/2);
Points_y = Points(:,(c/2+1):end);
size(Points_x)
size(Points_y)

temp=eye([3,6]);
temp1=zeros([3,6]);
I1=[temp ; temp1];
I2=eye([6 6])-I1;
clear temp; clear temp1

M_temp_x1=(Points_x*I1)';
M_temp_x2=(Points_x*I2)';
M_temp_y1=(Points_y*I1)';
M_temp_y2=(Points_y*I2)';
M_temp_I1=(ones(size(Points_x))*I1)';
M_temp_I2=(ones(size(Points_x))*I2)';
M=[M_temp_x1(:) M_temp_x2(:) M_temp_y1(:) M_temp_y2(:) M_temp_I1(:) M_temp_I2(:)]
size(M)
Points_Lab=repmat(500*[-1 ; -1 ; 1; 1; 1; 1],[(size(M,1)/6),1]);
size(Points_Lab)
Transformation = linsolve(M,Points_Lab)
c=Transformation;
syms x y
[x y]=solve([x*y == -(c(1)*c(3) + c(2)*c(4)) , x^2 - y^2 == (c(3)^2 -c(1)^2 +c(4)^2 -c(2)^2)], [x , y])

% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(~, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
