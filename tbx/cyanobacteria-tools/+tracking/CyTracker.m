classdef CYTracker < handle
    %FRETtracker  Tracks cells
    %
    %  This is the main class for the cell tracking module. Use this class
    %  to process a video to segment and track cells.
    %
    %  FRETtracker Properties:
    %  
    %  FRETtracker Methods:
    %      processVideo - Segment and track cells from a dataset
    %
    %  Example:
    %
    %  %Intialize a new FRETtracker object
    %  T = FRETtracker;
    %
    %  %Process a specified file
    %  T.processVideo(filename, outputDir, (optional) Parameter/Value)
    %
    %    
    %  See also: FRETtracker.processVideo
    %
    %  Copyright 2017 University of Colorado Boulder

    properties
        nuclearChan = 'mCherry';
        CFPChan = 'CFP_s';
        YFPChan = 'CFP-YFP Emi_s';
        
        CellType = 'NLS';
        
        ROI = 'full';
        
        %Output options
        OutputMovie = true;
        
        %First frame to process
        FrameRange = Inf;
        
        %Maximum and minimum nuclear area
        MinNucleusArea = 15;
        MaxNucleusArea = 5000;
        
        %Add the threshold level
        ThresholdLvl = NaN;
        
        %Only for NES cells
        CytoRingSize = 2;
        
        CorrectLocalBackground = true;
        NumBackgroundBlocks = [11 11];
        BgPrctile = 20;
        
        AutoAdjustNuclImg = false;
        
        ExportMasks = false;
        
        ParallelProcess = false;
        
        %Track linker options
        MaxLinkDistance = 200;
        MaxTrackAge = 2;
        TrackMitosis = true;
        MinAgeSinceMitosis = 2;
        MaxMitosisDistance = 30;
        MaxMitosisAreaChange = 0.3;
        LAPSolver = 'lapjv';
        
    end
    
    methods %Public methods
        
        function obj = FRETtracker
            %FRETtracker  Constructor function
            %
            %  T = FRETTRACKER will create a FRETtracker object T. This
            %  function will check that the BioformatsImage toolbox is
            %  installed, prompting the user to download it otherwise.
            
            if ~exist('BioformatsImage','file')
                error('FRETtracker:BioformatsImageNotInstalled',...
                    'A required toolbox ''BioformatsImage'' is not installed. Visit https://biof-git.colorado.edu/core-code/bioformats-image-toolbox/wikis/home to get the latest version.');
            end
            
        end
        
%         function processFile(obj,varargin)
%             %PROCESSVIDEO  Process a video file and track cells
%             %
%             %  PROCESSVIDEO(filename,outputDir) will run the segmentation
%             %  and cell tracking algorithms on the video file provided.
%             %  Output data will be saved to the outputDir specified.
%             %
%             %  The video file can either be an ND2 or a TIFF file. If it is
%             %  a TIFF file, the code expects it to be named following the
%             %  Spencer lab/Image Express convention:
%             %  row_col_1_channel_frame.tif.
%             %
%             %  The following additional options can be passed to the
%             %  function (defaults in parantheses):
%             %    mCherryChan ('mCherry') - mCherry channel name 
%             %    CFPChan ('CFP_s') - CFP channel name
%             %    YFPChan ('CFP-YFP Emi_s') - FRET channel name
%             %
%             %    CellType ('NLS') - Defines the quantities measured (see below)
%             %    BgFile ('') - Empty well file name (not used currently)
%             %
%             %    OutputMovie (true) - Save movie?
%             %    FrameRange (Inf) - Frames to process. Inf = all
%             % 
%             %    MinNucleusArea (15) - Min area to consider a nucleus
%             %    MaxNucleusArea (5000) - Max area
%             %
%             %    ThresholdLvl (NaN) - Greyscale to use as threshold. NaN =
%             %    automatically decided
%             %
%             %    CytoRingSize (2) - For NES/CDK2 only. Width of the cyto
%             %    ring
%             %    
%             %    CorrectLocalBackground (true) - Apply local background
%             %    correction?
%             %    NumBackgroundBlocks ([11 11]) - Number of blocks to split
%             %    background to
%             %    BgPrctile (20) - Percentile level to define background
%             %    level
%             %
%             %  Additional notes:
%             %    The mCherry channel is used to track the cells' position
%             %    and area (for mitosis detection).
%             % 
%             %    For NLS cells: the code measures the mean YFP and FRET
%             %    intensities within the nuclear mask
%             %
%             %    For NES cells: The code measures the mean YFP and FRET
%             %    intensities in a ring around the nucleus
%             %
%             %    For the CDK2 cells: The code measures the signal in the
%             %    nucleus and in a ring around the nucleus.
%             
%             %Parse input arguments
%             ip = inputParser;
%             ip.addOptional('Filename', '', @(x) exist(x,'file'));
%             ip.addOptional('OutputDir', '', @(x) ischar(x));
%             ip.KeepUnmatched = true;
%             ip.parse(varargin{:});
%             
%             if isempty(ip.Results.Filename)
%                 [filename,pathname] = uigetfile(...
%                     {'*.nd2', 'ND2 file (*.nd2)';...
%                     '*.tif', 'TIF file (*.tif)'},...
%                     'Select an ND2 or TIF file to process');
%                 
%                 if filename == 0
%                     %Dialog was cancelled, so do nothing
%                     return;
% %                     error('FRETtracker:processFile:NoFileSelected',...
% %                         'No file selected');
%                 end
%                 
%                 filename = fullfile(pathname, filename);
%             else
%                 filename = ip.Results.Filename;                    
%             end
%             
%             if isempty(ip.Results.OutputDir)
%                 outputDir = uigetdir(fileparts(filename),'Select output directory');
%                 
%                 if outputDir == 0
%                     %Dialog was cancelled, so do nothing
%                     return;
% %                     error('FRETtracker:processFile:NoOutputDirSelected',...
% %                         'No output directory selected');
%                 end
%                 
%             else
%                 outputDir = ip.Results.OutputDir;
%             end
%             
%             %Parse optional input arguments
%             if ~isempty(ip.Unmatched)
%                 obj.setOptions(ip.Unmatched);
%             end
%             
%             %Make the output directory if it doesn't already exist
%             if ~exist(outputDir,'dir')
%                 mkdir(outputDir);
%             end
%             
%             %Prompt user to check settings
%             obj.checkSettings;
%             
%             %Start the processing
%             obj.analyzeFile(filename, outputDir, obj.exportOptionsToStruct);
%  
%         end
        
        function processFiles(obj, varargin)
            %PROCESSFILES  Process the selected file(s)
            %
            %  T.PROCESSFILES(filelist) will process all the files
            %  specified.
            %
            %  T.PROCESSFILES will provide a pop-up box which will
            %  allow you to select multiple files.
            
            ip = inputParser;
            ip.addOptional('Filelist', '',@(x) ischar(x) || iscellstr(x));
            ip.addOptional('OutputDir', '',@(x) ischar(x) && ~ismember(x,properties(obj.Options)));
            ip.KeepUnmatched = true;
            ip.parse(varargin{:});
            
            %----- Get input files ----%
            %Get a directory if none was supplied
            if isempty(ip.Results.Filelist)

                [filelist,dataDir] = uigetfile(...
                    {'*.nd2; *.tif', 'Image files (*.nd2, *.tif)'},...
                    'Choose files to process',...
                    'MultiSelect', 'on');
                
                if ~iscellstr(filelist)
                    if filelist == 0
                        return;
                    end
                end
            else
                if ischar(ip.Results.Filelist)
                    filelist = {ip.Results.Filelist};
                else
                    filelist = ip.Results.Filelist;
                end
            end
            
            %----- Check for output directory -----%
            if isempty(ip.Results.OutputDir)
                outputDir = uigetdir(dataDir,'Select output directory');
            else
                outputDir = ip.Results.OutputDir;
            end
            
            %Make the output directory if it doesn't exist
            if ~exist(outputDir,'dir')
                mkdir(outputDir)
            end
            
            %----- Current settings -----%
            if ~isempty(ip.Unmatched)
                obj.setOptions(ip.Unmatched);
            end
            
            obj.checkSettings;
            
            %----- Process files -----%
            
            %Enable parallel processing (if selected)
            if obj.ParallelProcess
                nParWorkers = Inf;
                
                %Starts a parallel pool object one is not already running.
                %Otherwise it returns the current parallel pool.
                currParpool = gcp;
                
                %Attach the BioformatsImage object to the parallel pool
                %(otherwise it complains about not being able to locate the
                %JAR files).
                currParpool.addAttachedFiles('BioformatsImage','FRETtiffs','TrackLinker','CellTracks');
                
            else
                nParWorkers = 0;
            end
                        
            optionsStruct = obj.exportOptionsToStruct;
            
            if ~iscell(filelist) && ischar(filelist)
               filelist =  {filelist};
            end
            
            parfor (iF = 1:numel(filelist), nParWorkers)
                %Call the processing function
                FRETtracker.analyzeFile(fullfile(dataDir,filelist{iF}),outputDir, optionsStruct);
            end
            
        end
        
        function processDir(obj, varargin)
            %PROCESSDIR  Process all ND2 files in a specified directory
            %
            %  T.PROCESSDIR(dirName) will process all ND2 files in the
            %  specified directory
            %
            %  See also: FRETtracker.processVideo
            
            ip = inputParser;
            ip.addOptional('DataDir', '',@(x) exist(x,'dir'));
            ip.addOptional('OutputDir', '',@(x) char(x));
            ip.addParameter('ExcludeFiles', '', @(x) ischar(x) || iscellstr(x));
            ip.addParameter('IncludeFiles', '', @(x) ischar(x) || iscellstr(x));
            ip.KeepUnmatched = true;
            ip.parse(varargin{:});
            
            %----- Get input files ----%
            %Get a directory if none was supplied
            if isempty(ip.Results.DataDir)

                [~,dataDir] = uigetdir('','Select a directory with ND2 or TIF files');
                
                if dataDir == 0
                    error('FRETtracker:processDir:NoDirSelected',...
                        'No directory was selected.');
                end
            else
                dataDir = ip.Results.DataDir;
            end
            
            %Get list of ND2 files in the directory
            if ~isempty(ip.Results.IncludeFiles)
                
                %Look for files matching the pattern(s) specified
                if ~iscellstr(ip.Results.IncludeFiles)
                    includePatt = {ip.Results.IncludeFiles};
                else
                    includePatt = ip.Results.IncludeFiles;
                end
                
                for iIncFile = 1:numel(includePatt)
                   if ~exist('nd2FileList','var')
                        filelist = dir(fullfile(dataDir, includePatt{iIncFile}));
                    else
                        filelist = [filelist; ...
                            dir(fullfile(dataDir, includePatt{iIncFile}))]; %#ok<AGROW>
                    end
                end
                
                filelist = {filelist.name};

                %Make sure there are no duplicates
                filelist = unique(filelist);
            else
                %Include all ND2 files
                filelist = dir(fullfile(dataDir,'*.nd2'));
                
                if isempty(filelist)
                    %Try looking for TIF files (only get the names of the
                    %FRET channel tiff, frame 1)
                    filelist = dir(fullfile(dataDir,'*FRET_1.tif'));                   
                end
                
                filelist = {filelist.name};
            end
            
            %Remove excluded files (if they exist)
            if iscellstr(ip.Results.ExcludeFiles)
                excludedFiles = ip.Results.ExcludeFiles;
            elseif ischar(ip.Results.ExcludeFiles)
                excludedFiles = {ip.Results.ExcludeFiles};
            end
                        
            for iExFile = 1:numel(excludedFiles)
                matches = ~cellfun('isempty',regexp(filelist,excludedFiles{iExFile}));
                filelist(matches) = [];
            end
           
            %Check there are files to process
            if numel(filelist) == 0
                error('FRETtracker:processDir:NoImageFiles',...
                    'No unexcluded image files were found in folder ''%s''', dataDir);
            end
            
            %----- Check for output directory -----%
            if isempty(ip.Results.OutputDir)
                outputDir = uigetdir(dataDir,'Select output directory');
            else
                outputDir = ip.Results.OutputDir;
            end
            
            %Make the output directory if it doesn't exist
            if ~exist(outputDir,'dir')
                mkdir(outputDir)
            end
            
            %----- Current settings -----%
            if ~isempty(ip.Unmatched)
                obj.setOptions(ip.Unmatched);
            end
            
            obj.checkSettings;
            
            %----- Process files -----%
            
            %Enable parallel processing (if selected)
            if obj.ParallelProcess
                nParWorkers = Inf;
                
                %Starts a parallel pool object one is not already running.
                %Otherwise it returns the current parallel pool.
                currParpool = gcp;
                
                %Attach the BioformatsImage object to the parallel pool
                %(otherwise it complains about not being able to locate the
                %JAR files).
                currParpool.addAttachedFiles('BioformatsImage','FRETtiffs','TrackLinker','CellTracks');
                
            else
                nParWorkers = 0;
            end
            
            %Generate the options structure
            optStruct = obj.exportOptionsToStruct;            
            
            parfor (iF = 1:numel(filelist), nParWorkers)
                %Call the processing function
                FRETtracker.analyzeFile(fullfile(dataDir,filelist{iF}),outputDir,optStruct);
            end
            
        end
        
        function obj = setOptions(obj, varargin)
            %SETOPTIONS  Set options file
            %
            %  linkerObj = linkerObj.SETOPTIONS(parameter, value) will set
            %  the parameter to value.
            %
            %  linkerObj = linkerObj.SETOPTIONS(O) where O is a data object
            %  with the same property names as the options will work.
            %
            %  linkerObj = linkerObj.SETOPTIONS(S) where S is a struct
            %  with the same fieldnames as the options will also work.
            %
            %  Non-matching parameter names will be ignored.
            
            if numel(varargin) == 1 && isstruct(varargin{1})
                %Parse a struct as input
                
                inputParameters = fieldnames(varargin{1});
                
                for iParam = 1:numel(inputParameters)
                    if ismember(inputParameters{iParam},properties(obj))
                        obj.(inputParameters{iParam}) = ...
                            varargin{1}.(inputParameters{iParam});
                    else
                        %Just skip unmatched options
                    end
                    
                end
                
            elseif numel(varargin) == 1 && isobject(varargin{1})
                %Parse an object as input
                
                inputParameters = properties(varargin{1});
                
                for iParam = 1:numel(inputParameters)
                    if ismember(inputParameters{iParam},properties(obj))
                        obj.(inputParameters{iParam}) = ...
                            varargin{1}.(inputParameters{iParam});
                    else
                        %Just skip unmatched options
                    end
                    
                end
                
            else
                if rem(numel(varargin),2) ~= 0
                    error('Input must be Property/Value pairs.');
                end
                inputArgs = reshape(varargin,2,[]);
                for iArg = 1:size(inputArgs,2)
                    if ismember(inputArgs{1,iArg},properties(obj))
                        
                        obj.(inputArgs{1,iArg}) = inputArgs{2,iArg};
                    else
                        %Just skip unmatched options
                    end
                end
            end
        end
        
        function structOut = exportOptionsToStruct(obj)
            
            propList = properties(obj);
            for iP = 1:numel(propList)
                structOut.(propList{iP}) = obj.(propList{iP});
            end
            
        end
        
        function obj = importSettings(obj, filename)
            %IMPORTSETTINGS  Import settings from file
            %
            %  S = FRETtracker.IMPORTSETTINGS(filename) will import
            %  settings from the file specified. The file should be a txt
            %  file.
            
            fid = fopen(filename,'r');
            
            if fid == -1
                error('FRETtracker:importSettings:ErrorReadingFile',...
                    'Could not open file %s for reading.',filename);
            end
            
            while ~feof(fid)
                currLine = strtrim(fgetl(fid));
                
                if isempty(currLine)
                    %Empty lines should be skipped
                    
                elseif strcmpi(currLine(1),'%') || strcmpi(currLine(1),'#')
                    %Lines starting with '%' or '#' are comments, so ignore
                    %those
                    
                else
                    %Expect the input to be PARAM_NAME = VALUE
                    parsedLine = strsplit(currLine,'=');
                    
                    %Get parameter name (removing spaces)
                    parameterName = strtrim(parsedLine{1});
                    
                    %Get value name (removing spaces)
                    value = strtrim(parsedLine{2});
                    
                    if isempty(value)
                        %If value is empty, just use the default
                    else
                        obj = obj.setOptions(parameterName,eval(value));
                    end
                    
                end
                
            end
            
            fclose(fid);
            
        end
        
        function exportSettings(obj, exportFilename)
            %EXPORTSETTINGS  Export settings to a txt file
            %
            %  FRETtrackerOptions.EXPORTSETTINGS(filename) will export the
            %  settings to a txt file. If the filename is not provided, a
            %  dialog box will pop-up asking the user to select a location
            %  to save the file.
            
            if ~exist('exportFilename','var')
                
                [filename, pathname] = uiputfile({'*.txt','Text file (*.txt)'},...
                    'Select output file location');
                
                exportFilename = fullfile(pathname,filename);
                
            end
            
            fid = fopen(exportFilename,'w');
            
            if fid == -1
                error('FRETtrackerOptions:exportSettings:CouldNotOpenFile',...
                    'Could not open file to write')
            end
            
            propertyList = properties(obj);
            
            %Write output data depending on the datatype of the value
            for ii = 1:numel(propertyList)
                
                if ischar(obj.(propertyList{ii}))
                    fprintf(fid,'%s = ''%s'' \r\n',propertyList{ii}, ...
                        obj.(propertyList{ii}));
                    
                elseif isnumeric(obj.(propertyList{ii}))
                    fprintf(fid,'%s = %s \r\n',propertyList{ii}, ...
                        mat2str(obj.(propertyList{ii})));
                    
                elseif islogical(obj.(propertyList{ii}))
                    
                    if obj.(propertyList{ii})
                        fprintf(fid,'%s = true \r\n',propertyList{ii});
                    else
                        fprintf(fid,'%s = false \r\n',propertyList{ii});
                    end
                    
                end
                
            end
            
            fclose(fid);
            
        end
        
    end
    
    methods (Access = private)
        
        function checkSettings(obj)
            %CHECKSETTINGS  Confirm current settins with user
            %
            %  O.CHECKSETTINGS will display the current object properties
            %  and ask the user to confirm they are correct. If the user
            %  indicates they are not, the program will prompt for a
            %  settings file.
            
            %Display current settings and ask user to confirm whether to
            %continue
            promptForSettings = true;
            while promptForSettings
                
                disp(obj);
                
                startTrack = input('Verify that the settings are correct. Type ''(Y)es'' to begin or ''(L)oad'' to load a file: ','s');
                
                if (strcmpi(startTrack,'l') || strcmpi(startTrack,'load'))
                    
                        [filename, pathname] = uigetfile({'*.*','All files'},...
                            'Select the settings file');
                        
                        obj.importSettings(fullfile(pathname,filename));
                   
                elseif (strcmpi(startTrack,'y') || strcmpi(startTrack,'yes'))
                    %Proceed with the rest of the code
                    promptForSettings = false;
                    
                else
                    error('FRETtracker:processDir:UserIncorrectSettings',...
                        'Change settings then call processDir again.');
                end
            end
            
        end
        
    end
        
    methods (Static, Access = private)  %Segmentation and tracking functions
        
        function analyzeFile(filename, outputDir, optionsStruct)
            %ANALYZEFILE  Segment and track cells in the specified file
            %
            %  FRETtracker.ANALYZEFILE(filename, outputDir, optionsStruct)
            %  will run the segmentation and tracking algorithm on the
            %  specified file. Output files will be saved to the outputDir
            %  specified. 
            %
            %  Segmentation and tracking options have to be supplied using
            %  the optionsStruct structure.
            %
            %  Note: This method has been made Static to reduce memory
            %  usage. See
            %  https://stackoverflow.com/questions/45041783/referring-to-class-method-in-parfor-loop-significant-memory-usage
            %  Test case 2.
            
            %Determine the file extension. If it is .ND2, the code
            %initializes a BioformatsImage object to read the file. If it
            %is a TIFF/TIF, the code initializes a FRETtiffs object.
            [~,fname,ext] = fileparts(filename);
            switch lower(ext)
                
                case '.nd2'
                    bfReader = BioformatsImage(filename);
                    
                case {'.tiff','.tif'}
                    bfReader = FRETtiffs(filename);
                    
                    %Convert the filename to a well format
                    [~,fname] = fileparts(bfReader.filename);
                    
                otherwise
                    error('FRETtracker:analyzeFile:UnsupportedFileExtension',...
                        '%s: Unsupported file extension %s.',...
                        fname, ext)
                    
            end
            
            %Initialize the VideoWriter object if the option is set to save
            %a movie
            if optionsStruct.OutputMovie
                
                %Video Writer for the segmentation movie
                vidObjMask = VideoWriter(fullfile(outputDir,[fname,'_masks.avi']));
                vidObjMask.Quality = 100;
                vidObjMask.FrameRate = 10;
                open(vidObjMask);
                
                %Video Writer for the track movie
                vidObjTracks = VideoWriter(fullfile(outputDir,[fname,'_tracks.avi']));
                vidObjTracks.Quality = 100;
                vidObjTracks.FrameRate = 10;
                open(vidObjTracks);
                
            end
            
            %If masks are exported, create a sub-directory to store them
            if optionsStruct.ExportMasks
                if ~exist(fullfile(outputDir,'Masks'),'dir')
                    mkdir(fullfile(outputDir,'Masks'));
                end
            end
            
            %--- Begin processing code ---%
            %Determine the range of frames to process
            if isinf(optionsStruct.FrameRange)
                optionsStruct.FrameRange = 1:bfReader.sizeT;
            end
            
            numSkippedFrames = 0;   %Number of frames where no cells were found            
            for iT = optionsStruct.FrameRange
                
                %Load the images
                nuclImg = bfReader.getPlane(1, optionsStruct.nuclearChan, iT);
                YFPImg = bfReader.getPlane(1, optionsStruct.YFPChan, iT);
                
                %Only load the CFP image if we are tracking FRET
                if ~strcmpi(optionsStruct.CellType,'CDK2')
                    CFPImg = bfReader.getPlane(1, optionsStruct.CFPChan, iT);
                    
                    %Get data from each frame
                    [currData, nuclLabels] = FRETtracker.getFrameData(nuclImg,YFPImg,CFPImg,optionsStruct);
                else
                    [currData, nuclLabels] = FRETtracker.getFrameData(nuclImg,YFPImg,nan,optionsStruct);
                end
                
                %Link the data into tracks                
                if iT == optionsStruct.FrameRange(1)
                    %Initialize the tracker
                    trackerObj = TrackLinker;
                    trackerObj = trackerObj.setOptions(optionsStruct);
                    trackerObj = trackerObj.initializeTracks(iT,currData{:});
                else
                    try
                        %Assign data to tracks
                        trackerObj = trackerObj.assignToTrack(iT,currData{:});
                        
                        %Reset number of skipped frames
                        numSkippedFrames = 0;
                    catch ME
                        %If an error occurs during track assignment, try to
                        %continue if the issue is that no cell was found.
                        %If the error occurs three times in a row, then
                        %stop processing.
                        if all(nuclLabels(:) == 0)
                            numSkippedFrames = numSkippedFrames + 1;
                            
                            if numSkippedFrames > 3
                                error('FRETtracker:analyzeFile:NoCellsFound',...
                                    '%s(%d): No cells were found for three consecutive frames.',...
                                    fname,iT)                               
                            end
                        
                            warning('FRETtracker:analyzeFile:NoCellsFound',...
                                '%s(%d): No cells were found.',fname,iT)
                        else
                            error('FRETtracker:analyzeFile:ErrorDuringAssignment',...
                                '%s(%d): Track assignment error. Original error message:\n%s\n',...
                                fname, iT, ME.message);
                        end
                    end
                end
                
                if optionsStruct.OutputMovie
                    %Draw the current frame if saving a movie
                    fh = figure;
                    set(fh,'Visible','off')
                    FRETtracker.plotTracks(nuclImg,trackerObj,nuclLabels,iT);
                    set(fh,'units','normalized','outerposition',[0 0 1 1],'innerposition',[0 0 1 1],'Visible','off')
                    vidObjTracks.writeVideo(getframe(fh));
                    close(fh);
                   
                    %Generate the cell mask movie. This movie has the
                    %highest resolution but does not contain tracks or cell
                    %numbers. Dividing cells are colored red in the movie
                    %for five frames after division (will be division + 1).
                    imgOut = FRETtracker.makeMovieFrame(nuclImg,trackerObj,nuclLabels,iT);
                    vidObjMask.writeVideo(imgOut);
                end
                
                %If option is set, export the cell nuclei labels as a TIF
                %file in the sub-directory 'Masks'.
                if optionsStruct.ExportMasks
                    imwrite(nuclLabels,...
                        fullfile(outputDir,'Masks',sprintf('%s_%d.tif',fname,iT)));
                end
                
            end

            if optionsStruct.OutputMovie
                %Close the VideoWriter object
                close(vidObjMask)
                close(vidObjTracks)
            end
                        
            %--- Save data ----%
            trackData = trackerObj.tracks;
            metadata = optionsStruct;
            save(fullfile(outputDir,[fname,'.mat']),'trackData','metadata');
            
        end
        
        function [dataOut, nuclLabels] = getFrameData(nuclImg,YFPImg,CFPImg,optionsStruct)
            %GETFRAMEDATA  Measures data from the frame
            %
            %  data = FRETtracker.GETFRAMEDATA(NuclearImage, YFPimg,
            %  CFPimg, optionsStruct) will:
            %    (a) Perform local background correction if
            %    optionsStruct.correctLocalBackground = true
            %    (b) Call the segmentation function on nuclImg
            %    (c) Measure the appropriate data depending on
            %    optionsStruct.CellType
            %
            %  data is the data structure

            %Correct the local background (if options is set)
            if optionsStruct.CorrectLocalBackground
                
                YFPImgCorrected = FRETtracker.correctLocalBackground(YFPImg,...
                    optionsStruct.NumBackgroundBlocks,optionsStruct.BgPrctile);
                
                %Only correct the CFP image if it exists (i.e. this channel
                %does not exist for the CDK2 dataset so we can save some
                %time)
                if ~isnan(CFPImg)
                    CFPImgCorrected = FRETtracker.correctLocalBackground(CFPImg,...
                        optionsStruct.NumBackgroundBlocks,optionsStruct.BgPrctile);
                end
            end
            
            %Segment and label the cell nuclei
            nuclLabels = FRETtracker.getNuclLabels(nuclImg,optionsStruct.AutoAdjustNuclImg, [optionsStruct.MinNucleusArea, optionsStruct.MaxNucleusArea]);
                        
            nuclData = regionprops(nuclLabels,...
                {'Area','Centroid','PixelIdxList'});
        
            switch lower(optionsStruct.CellType)
                
                case 'nls'
                    
                    %Assemble the output data structure
                    dataStruct = struct('Centroid',{},'Area',{},'mCherryInt',{},'YFPInt',{},'CFPInt',{},'MaskID',{});
                    
                    %Measure data for the NLS cells
                    for iNucl = 1:numel(nuclData)
                        
                        newIdx = numel(dataStruct)+1;
                        dataStruct(newIdx).Centroid = nuclData(iNucl).Centroid;
                        dataStruct(newIdx).Area= nuclData(iNucl).Area;
                        
                        dataStruct(newIdx).mCherryInt = mean(nuclImg(nuclData(iNucl).PixelIdxList));
                        dataStruct(newIdx).YFPInt = mean(YFPImg(nuclData(iNucl).PixelIdxList));
                        dataStruct(newIdx).CFPInt = mean(CFPImg(nuclData(iNucl).PixelIdxList));
                        dataStruct(newIdx).MaskID = iNucl;
                        
                        %Background
                        if optionsStruct.CorrectLocalBackground
                            dataStruct(newIdx).YFPCorr = mean(YFPImgCorrected(nuclData(iNucl).PixelIdxList));
                            dataStruct(newIdx).CFPCorr = mean(CFPImgCorrected(nuclData(iNucl).PixelIdxList));
                        end
                        
                    end
                    
                case 'nes'
                    
                    %Assemble the output data structure
                    dataStruct = struct('Centroid',{},'Area',{},'mCherryInt',{},'YFPInt',{},'CFPInt',{},'MaskID',{});
                    
                    %Make the cyto ring mask
                    cytoRingMask = nuclLabels;
                    cytoRingMask = imdilate(cytoRingMask, strel('disk',optionsStruct.CytoRingSize));
                    cytoRingMask(cat(1,nuclData(isMaskValid).PixelIdxList)) = 0;
                   
                    %Measure data for the NES cells
                    for iNucl = 1:numel(nuclData)
                        
                        newIdx = numel(dataStruct)+1;
                        dataStruct(newIdx).Centroid = nuclData(iNucl).Centroid;
                        dataStruct(newIdx).Area = nuclData(iNucl).Area;  %This is always nuclear area
                        
                        currMask = (cytoRingMask == iNucl);
                       
                        dataStruct(newIdx).CytoRingArea = sum(find(currMask));

                        %Measure the raw intensity data in the cyto ring (no background
                        %correction)
                        dataStruct(newIdx).mCherryInt = mean(mean(nuclImg(nuclLabels == iNucl)));
                        dataStruct(newIdx).YFPInt = mean(mean(YFPImg(currMask)));
                        dataStruct(newIdx).CFPInt = mean(mean(CFPImg(currMask)));
                        dataStruct(newIdx).MaskID = iNucl;
                        
                        %Measure the background corrected data
                        if optionsStruct.CorrectLocalBackground
                            dataStruct(newIdx).YFPCorr = mean(mean(YFPImgCorrected(currMask)));
                            dataStruct(newIdx).CFPCorr = mean(mean(CFPImgCorrected(currMask)));
                        end
                        
                    end
                    
                case 'cdk2'
                    
                    %Assemble the output data structure
                    dataStruct = struct('Centroid',{},'Area',{},'mTurqInt',{},'YFPNucl',{},'YFPCyto',{},'MaskID',{});
                    
                    %Make the cyto ring mask
                    cytoRingMask = nuclLabels;
                    cytoRingMask = imdilate(cytoRingMask, strel('disk',optionsStruct.CytoRingSize));
                    cytoRingMask(cat(1,nuclData.PixelIdxList)) = 0;
                    
                    %Measure data for the NES cells
                    for iNucl = 1:numel(nuclData)
                        
                        newIdx = numel(dataStruct)+1;
                        dataStruct(newIdx).Centroid = nuclData(iNucl).Centroid;
                        dataStruct(newIdx).Area = nuclData(iNucl).Area;  %This is always nuclear area
                        dataStruct(newIdx).CytoRingArea = sum(find(cytoRingMask == iNucl));
                        dataStruct(newIdx).MaskID = iNucl;
                        
                        %Measure the nuclear signal
                        dataStruct(newIdx).mTurqInt = mean(nuclImg(cytoRingMask == iNucl));
                        
                        %Measure the raw intensity data in the nucleus
                        dataStruct(newIdx).YFPNucl = mean(YFPImg(nuclData(iNucl).PixelIdxList));
                        
                        %Measure the intensity in the cyto ring (no
                        %background correction)
                        dataStruct(newIdx).YFPCyto = mean(YFPImg(cytoRingMask == iNucl));
                        
                        %Measure the background corrected data
                        if optionsStruct.CorrectLocalBackground
                            %Nucleus
                            dataStruct(newIdx).YFPNuclCorr = mean(YFPImgCorrected(nuclData(iNucl).PixelIdxList));
                            
                            %Cyto ring
                            dataStruct(newIdx).YFPCytoCorr = mean(YFPImgCorrected(cytoRingMask == iNucl));
                        end
                        
                    end
                    
            end
           
            %This is temp until the tracking code is updated to handle
            %structures
            dataOut = {};
            propnames = fieldnames(dataStruct);
            for ii = 1:numel(propnames)
                if strcmpi(propnames{ii},'Centroid')
                    %Have to rename 'Centroid' to 'Position'
                    dataOut = {dataOut{:}, 'Position', cat(1,dataStruct.(propnames{ii}))};
                else
                    dataOut = {dataOut{:}, propnames{ii}, cat(1,dataStruct.(propnames{ii}))};
                end
            end
                
        end
        
        function plotTracks(nuclImg,trackerObj,nuclLabels,iT)
            %PLOTTRACKS  Shows an image with cell tracks overlaid
            %
            %  FRETtracker.PLOTTRACKS(nuclImg, trackerObj, nuclLabels, iT)

            warning off
            FRETtracker.showoverlay(FRETtracker.normalizeimg(imadjust(nuclImg)),bwperim(nuclLabels > 0),[0 1 0]);
            warning on
            
            hold on
            for iTrack = 1:numel(trackerObj)
                
                trackIdx = trackerObj.trackingInfo(iTrack).Index;
                
                currTrack = trackerObj.getTrack(trackIdx);
                
                if currTrack.StartFrame <= iT && currTrack.LastFrame >= iT
                    %If the cell exists in the current frame, label it by
                    %drawing the outline and inserting the text
                    
                    labelled = false;
                    if ~isnan(currTrack.MotherIdx)
                        currMother = trackerObj.getTrack(currTrack.MotherIdx);
                        
                        if (iT - currMother.LastFrame) <= 5
                            
                            text(currTrack.Position(end,1),currTrack.Position(end,2),int2str(trackIdx),'Color','b');
                            labelled = true;
                            
                        end
                    end
                    
                    if ~labelled
                        text(currTrack.Position(end,1),currTrack.Position(end,2),int2str(trackIdx),'Color','w');
                    end
                    
                end
                
            end
            hold off
            
        end
        
        function imgOut = makeMovieFrame(nuclImg, trackerObj, nuclLabels, iT)
            %MAKEMOVIEFRAME  Make an annotated movie frame
            %
            %  F = FRETtracker.MAKEMOVIEFRAME(I, T, L, T) draws a frame of
            %  the movie from the nuclear image I, the TrackLink object T,
            %  the nuclear label L, and the timepoint T. The function
            %  returns the labelled image F as a matrix.
            %
            %  The outlines will be blue if the nucleus divided recently
            %  (within the last 5 frames), or green otherwise.
           
            %Overlay the nuclei outlines on the image as green lines
            nuclImg = double(nuclImg);
            imgOut = FRETtracker.showoverlay(FRETtracker.normalizeimg(imadjust(nuclImg)),bwperim(nuclLabels > 0),[0 1 0]);
            
            %If the nucleus divided recently (within the last 5 frames)
            %label the outline of the image red.
            for iTrack = 1:numel(trackerObj)
                trackIdx = trackerObj.trackingInfo(iTrack).Index;
                currTrack = trackerObj.getTrack(trackIdx);
                
                if currTrack.StartFrame <= iT && currTrack.LastFrame >= iT
                    if ~isnan(currTrack.MotherIdx)
                        currMother = trackerObj.getTrack(currTrack.MotherIdx);
                        if (iT - currMother.LastFrame) <= 5
                            imgOut = FRETtracker.showoverlay(imgOut,bwperim(nuclLabels == currTrack.MaskID(end)),[1 0 0]);
                        end
                    end
                end
            end
            
        end
        
    end
    
    methods (Static)
        
        function nuclLabels = getNuclLabels(nuclImg, varargin)
            %GETNUCLLABELS  Labels the nuclear image
            %
            %  L = GETNUCLLABELS(I) segments and labels the foreground
            %  objects (i.e. cell nuclei) in image I.
            %
            %  L = GETNUCLLABELS(I, true) will set auto-contrast adjustment
            %  of the image before segmentation and labelling. The
            %  adjustment is carried out using 'imadjust', with no
            %  additional parameters.
            
            ip = inputParser;
            ip.addOptional('adjustNucl', false, @(x) islogical(x));
            ip.addOptional('NuclAreaRange', [0 Inf], @(x) numel(x) == 2 && x(2) > x(1));
            ip.parse(varargin{:});
            
            if ip.Results.adjustNucl
                %Automatically contast-adjust the image if set
                nuclImg = imadjust(nuclImg);
            end
                       
            %Get threshold
            thLvl = FRETtracker.getThreshold(nuclImg);
            
            %Make the foreground mask
            binMask = nuclImg > thLvl;

            %binMask = activecontour(imadjust(nuclImg),binMask);
            binMask = imopen(binMask,strel('disk',2));
            binMask = imfill(binMask,'holes');
            binMask = bwareaopen(binMask,50);

            %Generate the distance transform
            dd = -bwdist(~binMask);
            dd(~binMask) = -Inf;
            
            %Surpress minima that are above the threshold level
            dd = imhmin(dd,1.2);
            
            %Run the watershed algorithm
            nuclLabels = watershed(dd);
            
            %Remove labels which are intersecting the image border, or are
            %too small/large
            nuclLabels = imclearborder(nuclLabels);
            
            maskValidSize = bwareaopen(nuclLabels, ip.Results.NuclAreaRange(1));
            mask_tooLarge = bwareaopen(nuclLabels, ip.Results.NuclAreaRange(2));
            maskValidSize(mask_tooLarge) = 0;
                        
            nuclLabels(~maskValidSize) = 0;
            
%             FRETtracker.showoverlay(FRETtracker.normalizeimg(imadjust(nuclImg)),bwperim(nuclLabels),[0 1 0]);
%             keyboard
            
        end
                
        function thLvl = getThreshold(imageIn)
            %GETTHRESHOLD  Get a threshold for the image
            %
            %  T = FRETtracker.GETTHRESHOLD(I) gets a greyscale threshold
            %  level T for the image I.
            %
            %  Threshold is determined by looking at image histogram, then
            %  looking for the greyscale value where the maximum count
            %  drops to at least 20%.
            
            %Get the image intensity histogram
            binEdges = linspace(0,double(max(imageIn(:))),200);
            [nCnts, binEdges] = histcounts(imageIn(:),binEdges);
            binCenters = diff(binEdges) + binEdges(1:end-1);
            
            nCnts = smooth(nCnts,5);
            
            %Find the background peak count
            [bgCnt,bgLoc] = findpeaks(nCnts,'Npeaks',1,'SortStr','descend');
            
            %Find where the histogram counts drops to at least 20% of this value
            thLoc = find(nCnts(bgLoc:end) <= bgCnt * 0.01,1,'first');
            
            thLvl = binCenters(thLoc + bgLoc);
            
%             plot(binCenters,nCnts,binCenters(bgLoc),bgCnt,'x',[thLvl, thLvl],ylim,'r--');
%             keyboard
            
        end
        
        function correctedImg = correctLocalBackground(imageIn,numBlocks,bgPrctile)
            %CORRECTLOCALBACKGROUND  Apply local background correction
            %
            %  C = FRETtracker.CORRECTLOCALBACKGROUND(I, N, P) runs the
            %  local background correction algorithm on the image I,
            %  returning the background-corrected image C. N is the number
            %  of blocks (N = [Nrows, Ncols]) to divide the image into. P
            %  is the percentile used to estimate the background.
            %
            %  During image acquisition, uneven illumination due to
            %  microscope optics makes the objects at the center of the
            %  image appear brighter than objects at the edge. 
            %
            %  To correct for this, we use a method similar to the Spencer
            %  lab; The image is divided into a number of blocks. The local
            %  background is estimated by calculating the lowest percentile
            %  of intensities in the block.
                        
            %Take the median filter of the image to remove hotspots
            imageIn = double(medfilt2(imageIn,[3 3]));
            
            %Calculate the indices for each block
            blockHeight = floor(size(imageIn,1)/numBlocks(1));
            blockWidth = floor(size(imageIn,2)/numBlocks(2));
            
            blockRowIdxs = 1:blockHeight:size(imageIn,1);
            blockRowIdxs(end) = size(imageIn,1);
            
            blockColIdxs = 1:blockWidth:size(imageIn,2);
            blockColIdxs(end) = size(imageIn,2);
            
            %Make the background image
            bgImage = zeros(size(imageIn));
            for iRow = 1:numBlocks(1)
                for iCol = 1:numBlocks(2)
                    
                    croppedImg = imageIn(blockRowIdxs(iRow):blockRowIdxs(iRow+1),...
                        blockColIdxs(iCol):blockColIdxs(iCol+1));
                    
                    bgValue = prctile(croppedImg(:),bgPrctile);
                    
                    bgImage(blockRowIdxs(iRow):blockRowIdxs(iRow+1),...
                        blockColIdxs(iCol):blockColIdxs(iCol+1)) = ...
                        ones(size(croppedImg)) .* bgValue;
                    
                end
            end
            
            correctedImg = imageIn - bgImage;
        end
        
        function varargout = showoverlay(baseimage, mask, color, varargin)
            %SHOWOVERLAY    Plot an overlay mask on an image
            %
            %  FRETtracker.SHOWOVERLAY(IMAGE,MASK,COLOR) will plot an
            %  overlay specified by a binary MASK on the IMAGE. The color
            %  of the overlay is specified using a three element vector
            %  COLOR.
            %
            %  O = FRETtracker.SHOWOVERLAY(IMAGE,MASK,COLOR) will return
            %  the overlaid image to the variable O.
            
            if ~exist('color','var')
                color = [1 1 1]; %Default color of the overlay
            end
            
            if size(baseimage,3) == 3
                red = baseimage(:,:,1);
                green = baseimage(:,:,2);
                blue = baseimage(:,:,3);
                
            elseif size(baseimage,3) == 1
                red = baseimage;
                green = baseimage;
                blue = baseimage;
                
            else
                error('Image should be either NxNx1 (greyscale) or NxNx3 (rgb)')
            end
            
            %Make sure the mask is binary (anything non-zero becomes true)
            mask = (mask ~= 0);
            
            if isinteger(baseimage)
                maxInt = intmax(class(baseimage));
            else
                maxInt = 1;
            end
            
            red(mask) = color(1) .* maxInt;
            green(mask) = color(2) .* maxInt;
            blue(mask) = color(3) .* maxInt;
            
            %Concatenate the output
            outputImg = cat(3,red,green,blue);
            
            if nargout == 0
                imshow(outputImg,[])
            else
                varargout{1} = outputImg;
            end
        
        end
    
        function imageOut = normalizeimg(imageIn,varargin)
            %NORMALIZEIMG   Linear dynamic range expansion for contrast enhancement
            %   N = NORMALIZEIMG(I) expands the dynamic range (or contrast) of image I
            %   linearly to maximize the range of values within the image.
            %
            %   This operation is useful when enhancing the contrast of an image. For
            %   example, if I is an image with uint8 format, with values ranging from
            %   30 to 100. Normalizing the image will expand the values so that they
            %   fill the full dynamic range of the format, i.e. from 0 to 255.
            %
            %   The format of the output image N depends on the format of the input
            %   image I. If I is a matrix with an integer classs (i.e. uint8, int16), N
            %   will returned in the same format. If I is a double, N will be
            %   normalized to the range [0 1] by default.
            %
            %   N = NORMALIZEIMG(I,[min max]) can also be used to specify a desired
            %   output range. For example, N = normalizeimg(I,[10,20]) will normalize
            %   image I to have values between 10 and 20. In this case, N will be
            %   returned in double format regardless of the format of I.
            %
            %   In situations where most of the interesting image features are
            %   contained within a narrower band of values, it could be useful to
            %   normalize the image to the 5 and 95 percentile values.
            %
            %   Example:
            %       I = imread('cameraman.tif');
            %
            %       %Calculate the values corresponding to the 5 and 95 percentile of
            %       %values within the image
            %       PRC5 = prctile(I(:),5);
            %       PRC95 = prctile(I(:),95);
            %
            %       %Threshold the image values to the 5 and 95 percentiles
            %       I(I<PRC5) = PRC5;
            %       I(I>PRC95) = PRC95;
            %
            %       %Normalize the image
            %       N = normalizeimg(I);%
            %
            %       %Display the normalized image
            %       imshow(N)
            
            %Define default output value range
            outputMin = 0;
            outputMax = 1;
            
            %Check if the desired output range is set. If it is, make sure it contains
            %the right number of values and format, then update the output minimum and
            %maximum values accordingly.
            if nargin >= 2
                if numel(varargin{1}) ~= 2
                    error('The input parameter should be [min max]')
                end
                
                outputMin = varargin{1}(1);
                outputMax = varargin{1}(2);
            else
                %If the desired output range is not set, then check if the image is an
                %integer class. If it is, then set the minimum and maximum values
                %to match the range of the class type.
                if isinteger(imageIn)
                    inputClass = class(imageIn);
                    
                    outputMin = 0;
                    outputMax = double(intmax(inputClass)); %Get the maximum value of the class
                    
                end
            end
            
            %Convert the image to double for the following operations
            imageIn = double(imageIn);
            
            %Calculate the output range
            outputRange = outputMax - outputMin;
            
            %Get the maximum and minimum input values from the image
            inputMin = min(imageIn(:));
            inputMax = max(imageIn(:));
            inputRange = inputMax - inputMin;
            
            %Normalize the image values to fit within the desired output range
            imageOut = (imageIn - inputMin) .* (outputRange/inputRange) + outputMin;
            
            %If the input was an integer before, make the output image the same class
            %type
            if exist('inputClass','var')
                eval(['imageOut = ',inputClass,'(imageOut);']);
            end
            
        end
                
    end
    
end