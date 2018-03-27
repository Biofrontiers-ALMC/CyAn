function varargout = maskeditor(varargin)
% MASKEDITOR MATLAB code for maskeditor.fig
%      MASKEDITOR, by itself, creates a new MASKEDITOR or raises the existing
%      singleton*.
%
%      H = MASKEDITOR returns the handle to a new MASKEDITOR or the handle to
%      the existing singleton*.
%
%      MASKEDITOR('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MASKEDITOR.M with the given input arguments.
%
%      MASKEDITOR('Property','Value',...) creates a new MASKEDITOR or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before maskeditor_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to maskeditor_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help maskeditor

% Last Modified by GUIDE v2.5 26-Mar-2018 11:53:18

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @maskeditor_OpeningFcn, ...
                   'gui_OutputFcn',  @maskeditor_OutputFcn, ...
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


% --- Executes just before maskeditor is made visible.
function maskeditor_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to maskeditor (see VARARGIN)

% Choose default command line output for maskeditor
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes maskeditor wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = maskeditor_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --------------------------------------------------------------------
function menuFile_Callback(hObject, eventdata, handles)
% hObject    handle to menuFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function menuLoadND2_Callback(hObject, eventdata, handles)
% hObject    handle to menuLoadND2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[fname, fpath] = uigetfile({'*.nd2','Nikon Image Files (*.nd2)'},'Select Image File');

if fname == 0
    return;
end

setappdata(hObject, 'ImgReader', BioformatsImage(fullfile(fpath, fname)));
setappdata(hObject, 'baseImage', getappdata(hObject, 'ImgReader').getPlane(1, 1, 1));

imshow(getappdata(hObject, 'baseImage'), 'Parent', handles.axes1);


% --------------------------------------------------------------------
function menuLoadMask_Callback(hObject, eventdata, handles)
% hObject    handle to menuLoadMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[fname, fpath] = uigetfile({'*.tif; *.tiff','Nikon Image Files (*.tif, *.tiff)'},'Select Mask File');

if fname == 0
    return;
end

hObject.UserData.MaskFile = fullfile(fpath, fname);

hObject.UserData.CurrMask = imread(hObject.UserData.MaskFile,1);

showoverlay(hObject.UserData.CurrImg, hObject.UserData.CurrMask, 'Parent', handles.axes1);


function updateImage(hObject, evendata, handles)

if isempty(hObject.UserData.CurrImg)
    
    
elseif isempty(jObject.UserData.MaskFile)
    
else
    
    
    
end


% --------------------------------------------------------------------
function menuSaveMask_Callback(hObject, eventdata, handles)
% hObject    handle to menuSaveMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in btnDraw.
function btnDraw_Callback(hObject, eventdata, handles)
% hObject    handle to btnDraw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function menuMask_Callback(hObject, eventdata, handles)
% hObject    handle to menuMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function menuGenerateMask_Callback(hObject, eventdata, handles)
% hObject    handle to menuGenerateMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function menuDrawCylinders_Callback(hObject, eventdata, handles)
% hObject    handle to menuDrawCylinders (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in btnErase.
function btnErase_Callback(hObject, eventdata, handles)
% hObject    handle to btnErase (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of btnErase
