function varargout = editorFig(varargin)
%EDITORFIG MATLAB code file for editorFig.fig
%      EDITORFIG, by itself, creates a new EDITORFIG or raises the existing
%      singleton*.
%
%      H = EDITORFIG returns the handle to a new EDITORFIG or the handle to
%      the existing singleton*.
%
%      EDITORFIG('Property','Value',...) creates a new EDITORFIG using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to editorFig_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      EDITORFIG('CALLBACK') and EDITORFIG('CALLBACK',hObject,...) call the
%      local function named CALLBACK in EDITORFIG.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help editorFig

% Last Modified by GUIDE v2.5 26-Mar-2018 13:55:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @editorFig_OpeningFcn, ...
                   'gui_OutputFcn',  @editorFig_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
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


% --- Executes just before editorFig is made visible.
function editorFig_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for editorFig
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes editorFig wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = editorFig_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
