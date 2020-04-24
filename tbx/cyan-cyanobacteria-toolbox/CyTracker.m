classdef CyTracker < handle
    %CYTRACKER  Class to process movies of cyanobacteria cells
    %
    %  OBJ = CYTRACKER creates a new CyTracker object to process, segment,
    %  and track cyanobacteria cells in time-lapse movies. 
    %
    %  Example:
    %  %Create a new CyTracker object
    %  CT = CyTracker;
    %
    %  %Change properties to adjust settings
    %  CT.ChannelToSegment = 'Red';
    %  CT.SegMode = 'Brightfield';
    %  CT.ThresholdLevel = 10;
    %
    %  %Call the method process(). A dialog box will pop up allowing you to
    %  %select files you want to process, as well as prompting you to
    %  %select the output directory
    %  process(CT);
    %
    %  Please see the wiki for usage instructions: 
    %  https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox/wikis/home
    %
    %  Copyright 2018 - 2020 CU Boulder and the Cameron Lab
        
    properties
        
        %Image options
        FrameRange double = Inf;
        SeriesRange double = Inf;
        OutputMovie logical = true;
        
        UseMasks logical = false;
        InputMaskDir char = '';
                
        RegisterImages logical = false;
        ChannelToRegister = 'Cy5';
        SaveMasks logical = false;
        
        ImageReader = 'bioformats';  %Or 'nd2sdk'
        
        %Segmentation options
        ChannelToSegment = '';
        SegMode char = '';
        ThresholdLevel double = 1.4;
        
        MaxCellMinDepth double = 5;
        CellAreaLim(1,2) double = [500 3500];
        
        %Spot detection options
        SpotChannel char = '';
        SpotSegMode char = '';
        SpotThreshold double = 2.5;
        SpotBgSubtract logical = false;
        MinSpotArea double = 4;
        
        UseSpotMask logical = false;
        SpotMaskDir char = '';
        
        DoGSpotDiameter double = 2;
        SpotErodePx double = 0;
        
        SpotCNR = 1.5;
        
        %Track linking parameters
        LinkedBy char = 'PixelIdxList';
        LinkCalculation char = 'pxintersect';
        LinkingScoreRange(1,2) double = [1, 8];
        MaxTrackAge double = 2;
        
        %Mitosis detection parameters
        TrackDivision logical = true;
        MinAgeSinceDivision double = 2;
        DivisionParameter char = 'PixelIdxList';          %What property is used for mitosis detection?
        DivisionCalculation char = 'pxintersect';
        DivisionScoreRange(1,2) double = [1, 8];
        LAPSolver char = 'lapjv';
        
        %Parallel processing options
        EnableParallel logical = false;
        MaxWorkers double = Inf;
        SwapZandT logical = false;
        
    end
        
    methods
        
        function obj = CyTracker(varargin)
            %CYTRACKER  Object to track and segment cyanobacteria cells
            
        end
        
        function process(obj, varargin)
            %PROCESS  Run segmentation and tracking on ND2 files
            %
            %  PROCESS(OBJ) will run the segmentation and tracking
            %  operations using the current settings in CObj. A dialog box
            %  will appear prompting the user to select ND2 file(s) to
            %  process, as well as the output directory.
            %
            %  PROCESS(OBJ, FILE1, ..., FILEN, OUTPUTDIR) will run the
            %  processing on the file(s) specified. Note that the files do
            %  not need to be in the same directory. The output files will
            %  be written to OUTPUTDIR.
            %
            %  PROCESS(OBJ, {FILE1, FILE2}, FILE3, ..., FILEN, OUTPUTDIR)
            %  will merge FILE1 and FILE2.

            %--- Validate file inputs---%
            if isempty(varargin)
                %If input is empty, prompt user to select file(s) and
                %output directory
                
                [fname, fpath] = uigetfile({'*.nd2; *.tif; *.tiff', 'Image files (*.nd2; *.tif; *.tiff)'; ...
                    '*.nd2','ND2 files (*.nd2)';...
                    '*.tif; *.tiff', 'TIFF files (*.tif; *.tiff)'},...
                    'Select a file','multiSelect','on');
                
                if isequal(fname,0) || isequal(fpath,0)
                    %User pressed cancel
                    return;
                end
                
                %Append the full path to the selected file(s)
                if iscell(fname)
                    for ii = 1:numel(fname)
                        fname{ii} = fullfile(fpath,fname{ii});
                    end
                else
                    fname = {fullfile(fpath,fname)};
                end
               
                %Prompt for mask directory
                if obj.UseMasks && isempty(obj.InputMaskDir)
                    obj.InputMaskDir = uigetdir(fileparts(fname{1}), 'Select mask directory');
                    
                    if isequal(obj.InputMaskDir,0)
                        return;
                    end
                end                
                
                %Get output directory
                outputDir = uigetdir(fileparts(fname{1}), 'Select output directory');
                
                if isequal(outputDir,0)
                    return;
                end
                
            elseif numel(varargin) >= 2
                
                %Check that the last argument is not a file (i.e. has no
                %.ext)
                [~, ~, lastFext] = fileparts(varargin{end});
                if ~isempty(lastFext)                    
                    error('CyTracker:OutputDirNeeded', ...
                        'An output directory must be specified.')
                end
                
                %Check that the InputMaskDir property is set if masks are
                %present
                if obj.UseMasks && isempty(obj.InputMaskDir)
                    error('CyTracker:InputMaskDirNotSet', ...
                        'The InputMaskDir property must be set to the mask path.')
                end
                                
                fname = varargin(1:end - 1);
                
                outputDir = varargin{end};
                
                if isempty(outputDir)
                    %If dir was empty, then use the current dir as the
                    %output path
                    outputDir = pwd;                    
                end
                
                if ~exist(outputDir, 'dir')
                    mkdir(outputDir);                    
                end
                                
            else
                error('CyTracker:InsufficientInputs', ...
                    'Expected number of inputs to be zero or a minimum of 2.')
            end

            %Compile the options into a struct
            options = obj.getOptions;           

            %Process the files
            if obj.EnableParallel
                
                parfor (iF = 1:numel(fname), obj.MaxWorkers)
                    try
                        CyTracker.trackFile(fname{iF}, outputDir, options);
                    catch ME
                        fprintf('%s %s: An error occured:\n', datestr(now), fname{iF});
                        fprintf('%s \n',getReport(ME,'extended','hyperlinks','off'));
                    end
                end
                
            else
                
                for iF = 1:numel(fname)
                    try
                        CyTracker.trackFile(fname{iF}, outputDir, options);
                    catch ME
                        fprintf('%s %s: An error occured:\n', datestr(now), fname{iF});
                        fprintf('%s \n',getReport(ME,'extended','hyperlinks','off'));
                    end
                end
                
            end
            
            %Save the settings file
            obj.exportOptions(fullfile(outputDir,'settings.txt'));
            
        end
        
        function mergeprocess(obj, varargin)
            %MERGEPROCESS  Merge and process two files
            %
            %  MERGEPROCESS(OBJ) will run the segmentation and tracking
            %  operations using the current settings in OBJ. A dialog box
            %  will appear prompting the user to select ND2 file(s) to
            %  process, as well as the output directory.
            %
            %  MERGEPROCESS(OBJ, FILE1, ..., FILEN, OUTPUTDIR) will run the
            %  processing on the file(s) specified. Note that the files do
            %  not need to be in the same directory. The output files will
            %  be written to OUTPUTDIR.

            %--- Validate file inputs---%
            if isempty(varargin)
                %If input is empty, prompt user to select file(s) and
                %output directory
                
                [fname, fpath] = uigetfile({'*.nd2','ND2 file (*.nd2)'},...
                    'Select a file','multiSelect','on');
                
                if isequal(fname,0) || isequal(fpath,0)
                    %User pressed cancel
                    return;
                end
                
                %Append the full path to the selected file(s)
                if iscell(fname)
                    for ii = 1:numel(fname)
                        fname{ii} = fullfile(fpath,fname{ii});
                    end
                else
                    fname = {fullfile(fpath,fname)};
                end
                
                %Prompt for mask directory
                if obj.UseMasks && isempty(obj.InputMaskDir)
                    obj.InputMaskDir = uigetdir(fileparts(fname{1}), 'Select mask directory');
                    
                    if isequal(obj.InputMaskDir,0)
                        return;
                    end
                end
                
                %Get output directory
                outputDir = uigetdir(fileparts(fname{1}), 'Select output directory');
                
                if isequal(outputDir,0)
                    return;
                end
                
            elseif numel(varargin) >= 2
                
                %Check that the last argument is not a file (i.e. has no
                %.ext)
                [~, ~, lastFext] = fileparts(varargin{end});
                if ~isempty(lastFext)
                    error('CyTracker:OutputDirNeeded', ...
                        'An output directory must be specified.')
                end
                
                %Check that the InputMaskDir property is set if masks are
                %present
                if obj.UseMasks && isempty(obj.InputMaskDir)
                    error('CyTracker:InputMaskDirNotSet', ...
                        'The InputMaskDir property must be set to the mask path.')
                end
                
                fname = varargin(1:end - 1);
                
                outputDir = varargin{end};
                
                if isempty(outputDir)
                    %If dir was empty, then use the current dir as the
                    %output path
                    outputDir = pwd;
                end
                
                if ~exist(outputDir, 'dir')
                    mkdir(outputDir);
                end
                
            else
                error('CyTracker:InsufficientInputs', ...
                    'Expected number of inputs to be zero or a minimum of 2.')
            end

            %Compile the options into a struct
            options = obj.getOptions;           

            %Process the files
            CyTracker.trackFile(fname, outputDir, options);
            
            %Save the settings file
            obj.exportOptions(fullfile(outputDir,'settings.txt'));
            
        end
        
        function importOptions(obj, varargin)
            %IMPORTOPTIONS  Import options from file
            %
            %  IMPORTOPTIONS(OBJ, FILENAME) will load the options from the
            %  file specified.
            %
            %  IMPORTOPTIONS(OBJ) will open a dialog box for the user to
            %  select the option file.
            
            %Get the options file
            if isempty(varargin)                
                [fname, fpath] = uigetfile({'*.txt','Text file (*.txt)';...
                    '*.*','All files (*.*)'},...
                    'Select settings file');
                
                if fname == 0
                    return;                    
                end
                
                optionsFile = fullfile(fpath,fname);
                
            elseif numel(varargin) == 1
                optionsFile = varargin{1};
                
            else
                error('CyTracker:TooManyInputs', 'Too many input arguments.');
                
            end
            
            fid = fopen(optionsFile,'r');
            
            if isequal(fid,-1)
                error('CyTracker:ErrorReadingFile',...
                    'Could not open file %s for reading.',optionsFile);
            end
            
            ctrLine = 0;
            while ~feof(fid)
                currLine = strtrim(fgetl(fid));
                ctrLine = ctrLine + 1;
                
                if isempty(currLine) || strcmpi(currLine(1),'%') || strcmpi(currLine(1),'#')
                    %Empty lines should be skipped
                    %Lines starting with '%' or '#' are comments, so ignore
                    %those
                    
                else
                    
                    parsedLine = strsplit(currLine,'=');
                    
                    %Check for errors in the options file
                    if numel(parsedLine) < 2 
                        error('CyTracker:ErrorReadingOption',...
                            'Error reading <a href="matlab:opentoline(''%s'', %d)">file %s (line %d)</a>',...
                            optionsFile, ctrLine, optionsFile, ctrLine);
                    elseif isempty(parsedLine{2})
                        error('CyTracker:ErrorReadingOption',...
                            'Missing value in <a href="matlab:opentoline(''%s'', %d)">file %s (line %d)</a>',...
                            optionsFile, ctrLine, optionsFile, ctrLine);
                    end
                    
                    %Get parameter name (removing spaces)
                    parameterName = strtrim(parsedLine{1});
                    
                    %Get value name (removing spaces)
                    value = strtrim(parsedLine{2});
                    
                    if isempty(value)
                        %If value is empty, just use the default
                    else
                        obj.(parameterName) = eval(value);
                    end
                    
                end
                
            end
            
            fclose(fid);
        end
        
        function exportOptions(obj, exportFilename)
            %EXPORTOPTIONS  Export tracking options to a file
            %
            %  L.EXPORTOPTIONS(filename) will write the currently set
            %  options to the file specified. The options are written in
            %  plaintext, no matter what the extension of the file is.
            %
            %  L.EXPORTOPTIONS if the filename is not provided, a dialog
            %  box will pop-up asking the user to select a location to save
            %  the file.
            
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
            
            %First, write the date
            fprintf(fid,'%s %s \r\n','%Processed on', date);
            
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
        
        function exportMasks(obj, varargin)
            %EXPORTMASKS  Segment and export cell masks
            %
            %  EXPORTMASKS(PT) will export the cell masks of the selected
            %  images to the output directory specified. Both images and
            %  output directory can be selected using a dialog box pop up.
            %
            %  EXPORTMASKS(PT, fileList, outputDir) where fileList is a
            %  cell array of strings containing paths to the file, and
            %  outputDir is the path to save the masks to.
            %
            %  EXPORTMASKS(PT, ..., 'spotonly') will only save the spot
            %  masks.
            %
            %  EXPORTMASKS(PT, ..., 'cellonly') will only save the cell
            %  masks.
            %
            %  EXPORTMASKS(PT, ..., 'all') will only save both spot and
            %  cell masks (default behavior).
            
            exportType = 'all';
            exportRaw = false;
            outputDir = 0;
            filename = '';
            
            %TODO: Add cell masks
            opts = getOptions(obj);
            
            %Parse optional inputs
            if ~isempty(varargin)
                for ii = 1:numel(varargin)
                    
                    switch lower(varargin{ii})
                        
                        case {'spotonly', 'cellonly', 'all'}
                            exportType = lower(varargin{ii});
                            
                        case 'raw'
                            exportRaw = true;
                            
                        otherwise
                            
                            if isfolder(varargin{ii}) && (outputDir == 0)
                                outputDir = varargin{ii};
                            elseif (iscell(varargin{ii}) || exist(varargin{ii},'file')) && isempty(filename)
                                filename = varargin{ii};
                            end
                            
                    end
                end
            end
            
            if isempty(filename)
                [fname, fpath] = uigetfile({'*.nd2','ND2 file (*.nd2)'},...
                    'Select a file','multiSelect','on');
                
                if ~iscell(fname) && ~ischar(fname)
                    %Stop running the script
                    return;
                end
                
                if iscell(fname)
                    filename = cell(1, numel(fname));
                    for ii = 1:numel(fname)
                        filename{ii} = fullfile(fpath,fname{ii});
                    end
                else
                    filename = {fullfile(fpath,fname)};
                end
            elseif ~iscell(filename)
                filename = {filename};                
            end
                        
            %Prompt user for a directory to save output files to
            if outputDir == 0
                startPath = fileparts(filename{1});
                
                outputDir = uigetdir(startPath, 'Select output directory');
                
                if outputDir == 0
                    %Processing cancelled
                    return;
                end
            end
            
            for iFile = 1:numel(filename)                
                fprintf('%s: Exporting masks of file %s\n', ...
                    datestr(now), filename{iFile});
                
                
                [~, currFN] = fileparts(filename{iFile});
                
                if strcmpi(obj.ImageReader, 'nd2sdk')
                    bfr = ND2reader(filename{iFile});
                else
                    bfr = BioformatsImage(filename{iFile});
                end
                
                if obj.SwapZandT
                    bfr.swapZandT = true;                    
                end
                
                %Get frame range
                if isinf(obj.FrameRange)
                    frameRange = 1:bfr.sizeT;
                else
                    frameRange = obj.FrameRange;
                end
                
                %Get series range
                if isinf(obj.SeriesRange)
                    seriesRange = 1:bfr.seriesCount;
                else
                    seriesRange = obj.SeriesRange;
                end
                
                for iSeries = seriesRange
                    
                    bfr.series = iSeries;
                    
                    %For 'nicksversion' of segmentation, if using auto
                    %threshold finding
                    if strcmpi(obj.SegMode, 'CyTracker.nickSeg') && obj.ThresholdLevel == inf
                        obj.ThresholdLevel = findBgStDevThLvl(obj, filename{iFile});
                    elseif ~strcmpi(obj.SegMode, 'CyTracker.nickSeg') && obj.ThresholdLevel == inf
                        error('Cannot have infinite threshold level in SegModes other than CyTracker.nickSeg. Change SegMode to CyTracker.nickSeg and use inf threshold level for auto thresholding.')
                    end
                    
                    for iT = frameRange
                        
                        %Read in the image
                        if ~iscell(opts.ChannelToSegment)
                            opts.ChannelToSegment = {opts.ChannelToSegment};
                        end
                        
                        imgToSegment = zeros(bfr.height, bfr.width, numel(opts.ChannelToSegment), 'uint16');
                        for iC = 1:numel(opts.ChannelToSegment)
                            imgToSegment(:, :, iC) = (bfr.getPlane(1, opts.ChannelToSegment{iC}, iT));
                        end
                        
                        
                        %Segment the cells
                        currCellMask = CyTracker.getCellLabels(...
                            imgToSegment, ...
                            obj.ThresholdLevel, obj.SegMode, ...
                            obj.MaxCellMinDepth, obj.CellAreaLim, exportRaw);
                        
                        %Normalize the mask
                        outputMask = currCellMask > 0;
                        outputMask(boundarymask(currCellMask)) = 0;
                        %outputMask = uint8(outputMask) .* 255;
                        
                        if exportRaw
                            outputMask = bwmorph(outputMask,'skel', Inf);
                            
                        end
                        
                        if ismember(exportType, {'cellonly', 'all'})
                            
                            %Normalize the image and convert to uint8
                            imgToExport = bfr.getPlane(1, 'Cy5', iT);
                            outputImg = uint8(double(imgToExport)./double(max(imgToExport(:))) .* 255);
                            
                            %Write to TIFF stack
                            maskOutputFN = fullfile(outputDir, sprintf('%s_series%d_cellMask.tif', currFN, iSeries));
                            imageOutputFN = fullfile(outputDir, sprintf('%s_series%d_cy5.tif', currFN, iSeries));
                            
                            if iT == frameRange(1)
                                imwrite(outputMask, maskOutputFN, 'compression', 'none');
                                imwrite(outputImg, imageOutputFN, 'compression', 'none');
                            else
                                imwrite(outputMask, maskOutputFN, 'writeMode', 'append', 'compression', 'none');
                                imwrite(outputImg, imageOutputFN, 'writeMode', 'append', 'compression', 'none');
                            end
                            
                        end
                        
                        if ismember(exportType, {'spotonly', 'all'}) && ~isempty(obj.SpotChannel)
     
                            spotOutputFN = fullfile(outputDir, sprintf('%s_series%d_spotMask.tif', currFN, iSeries));
                            
                            spotImg = bfr.getPlane(1, obj.SpotChannel, iT);
                            
                            spotMask = CyTracker.segmentSpots(spotImg, ...
                                currCellMask, opts);
                            
                            if iT == frameRange(1)
                                imwrite(spotMask, spotOutputFN, 'compression', 'none');
                            else
                                imwrite(spotMask, spotOutputFN, 'writeMode', 'append', 'compression', 'none');
                            end
                        
                        end
                        
                    end
                end
            end
            
        end

    end
    
    methods (Static)

        function trackFile(filename, outputDir, opts)
            %TRACKFILE  Run segmentation and tracking for a selected file
            %
            %  TRACKFILE(FILENAME, OUTPUTDIR, OPTS) will run the processing
            %  for the FILENAME specified. OUTPUTDIR should be the path to
            %  the output directory, and OPTS should be a struct containing
            %  the settings for segmentation and tracking.
            %
            %  The OPTS struct can be constructed from a CYTRACKER object
            %  by using the (private) getOptions function.
            %
            %  To handle multiple files, make filename into a cell:
            %
            %  %Single file
            %  trackFileMerge('file1.nd2', outputDir, opts)
            %  trackFileMerge({'file1.nd2'}, outputDir, opts)
            %  
            %  %Merge Multiple files
            %  trackFileMerge({'file1.nd2', 'file2.nd2'}, outputDir, opts)
            
            %Convert single file into cell array if it's not already for
            %compatibility with the for loop
            if ~iscell(filename)
                filename = {filename};                
            end
            
            %Validate the series range
            if isinf(opts.SeriesRange)
                
                %Get a reader object for the image
                if strcmpi(opts.ImageReader, 'nd2sdk')
                    reader = ND2reader(filename{1});
                else
                    reader = BioformatsImage(filename{1});
                end
                
                opts.SeriesRange = 1:reader.seriesCount;
                
            end
            
            %Warn about frame range if files are being merged
            if numel(filename) > 1 && ~isinf(opts.FrameRange)
                %Warn that not processing every frame currently not
                %supported
                warning('CyTracker:trackFile:CustomFrameRangeNotSupported', ...
                    'A custom frame range is not currently supported when merging multiple files. Setting FrameRange to Inf.');
                
                opts.FrameRange = Inf;
            end
            
            %Start processing
            for iSeries = opts.SeriesRange
                
                %Generate output filename (no extension)
                [~, fname] = fileparts(filename{1});
                if numel(filename) == 1
                    saveFN = fullfile(outputDir, sprintf('%s_series%d', fname, iSeries));
                elseif numel(filename) > 1
                    saveFN = fullfile(outputDir, sprintf('%s_series%d_merged', fname, iSeries));
                end
                
                %Reset frame offset (for handling merging of multiple
                %files)
                frameOffset = 0;
                
                %Initialize a new object for tracking
                Linker = LAPLinker;
                Linker.LinkedBy = opts.LinkedBy;
                Linker.LinkCostMetric = opts.LinkCalculation;
                Linker.LinkScoreRange = opts.LinkingScoreRange;
                Linker.MaxTrackAge = opts.MaxTrackAge;
                Linker.TrackDivision = opts.TrackDivision;
                Linker.DivisionParameter = opts.DivisionParameter;
                Linker.DivisionScoreMetric = opts.DivisionCalculation;
                Linker.DivisionScoreRange = opts.DivisionScoreRange;
                Linker.MinFramesBetweenDiv = opts.MinAgeSinceDivision;

                %Create a vector to hold timestamp information
                timestamps = [];
                
                for iFile = 1:numel(filename)
                    
                    [~, currfilename] = fileparts(filename{iFile});
                    
                    %Get a reader object for the image
                    if strcmpi(opts.ImageReader, 'nd2sdk')
                        reader = ND2reader(filename{iFile});
                    else
                        reader = BioformatsImage(filename{iFile});
                    end
                    
                    %Change series
                    reader.series = iSeries;
                    
                    if iFile == 1
                    
                        %Update common file metadata
                        Linker = updateMetadata(Linker, 'Filename', reader.filename, ...
                            'PhysicalPxSize', reader.pxSize, ...
                            'PhysicalPxSizeUnits', reader.pxUnits, ...
                            'ImageSize', [reader.height, reader.width], ...
                            'ProcessingSettings', opts);
                    end
                    
                    %Get timestamp information
                    [ts, tsunit] = reader.getTimestamps(1,1);
                    timestamps = [timestamps, ts(opts.FrameRange)];  %#ok<AGROW>
                    
                    %Set the frame range to process
                    if isinf(opts.FrameRange)
                        frameRange = 1:reader.sizeT;
                    else
                        frameRange = opts.FrameRange;
                    end
                    
                    %Print progress statement
                    fprintf('%s %s (series %.0f): Started processing.\n', datestr(now), filename{iFile}, iSeries);
                    
                    %--- Start tracking ---%
                    for frame = frameRange
                        
                        %Read in the channels to segment
                        if ~iscell(opts.ChannelToSegment)
                            opts.ChannelToSegment = {opts.ChannelToSegment};
                        end

                        imgToSegment = zeros(reader.height, reader.width, numel(opts.ChannelToSegment), 'uint16');
                        for iC = 1:numel(opts.ChannelToSegment)
                            imgToSegment(:, :, iC) = (reader.getPlane(1, opts.ChannelToSegment{iC}, frame));
                        end
                        
                        if ~opts.UseMasks
                            %Segment the cells
                            cellLabels = CyTracker.getCellLabels(imgToSegment, ...
                                opts.ThresholdLevel, opts.SegMode,...
                                opts.MaxCellMinDepth, opts.CellAreaLim);
                            
                            %Write masks to file
                            if opts.SaveMasks
                                if iT == frameRange(1)
                                    imwrite(cellLabels, [saveFN, 'cellMask.tif'], 'Compression', 'None');
                                else
                                    imwrite(cellLabels, [saveFN, 'cellMask.tif'], ...
                                        'Compression', 'None', 'WriteMode', 'append');
                                end
                            end
                            
                        else
                            %Load the masks
                            mask = imread(fullfile(opts.InputMaskDir, sprintf('%s_series%d_cellMask.tif',currfilename, iSeries)),'Index', frame);
                            mask = mask > 0;
                            cellLabels = labelmatrix(bwconncomp(mask(:,:,1)));
                        end
                        
                        %Run spot detection if the SpotChannel property is set
                        if ~isempty(opts.SpotChannel)
                            
                            if opts.UseSpotMask
                                %Load the spot masks
                                dotLabels = imread(fullfile(opts.SpotMaskDir, sprintf('%s_series%d_spotMask.tif',currfilename, iSeries)),'Index', iT);
                                dotImg = dotLabels > 0;
                                
                            else
                                dotImg = reader.getPlane(1, opts.SpotChannel, frame);
                                
                                %Run dot finding algorithm
                                dotLabels = CyTracker.segmentSpots(dotImg, cellLabels, opts);
                                
                                if opts.SaveMasks
                                    if iT == frameRange(1)
                                        imwrite(dotLabels, [saveFN, 'spotMask.tif'], ...
                                            'Compression', 'None', 'WriteMode', 'append');
                                    else
                                        imwrite(dotLabels, [saveFN, 'spotMask.tif'], ...
                                            'Compression', 'None', 'WriteMode', 'append');
                                    end
                                end
                            end
                        else
                            dotLabels = [];
                        end
                        
                        %Compute the pixel shift to register image
                        if opts.RegisterImages
                            
                            pxShift = [0 0];
                            
                            %Get the image to register against. Works best for
                            %Cy5 fluorescence channel.
                            regImg = reader.getPlane(1, opts.ChannelToRegister, frame);
                            
                            if exist('prevImage', 'var')
                                pxShift = CyTracker.xcorrreg(prevImage, regImg);
                                %pxShiftTotal = pxShiftTotal - pxShift;
                                regImg = CyTracker.shiftimg(regImg, pxShift);
                            end
                            
                            %Store the image as a reference
                            prevImage = regImg;
                            
                        else
                            pxShift = [];
                        end
                        
                        %Run the measurement function
                        cellData = CyTracker.measure(cellLabels, dotLabels, reader, frame, pxShift);
                        
                        %Add detected objects to tracks
                        if numel(cellData) == 0
                            %Skip if no cells were found
                            warning('CyTracker:NoCellsFound', '%s (frame %d): Cell mask was empty.',filename{iFile}, frame);
                        else
                            
                            try
                                %Adjust frame offset (for merging files)
                                iT = frame + frameOffset;
                                
                                %Link data to existing tracks
                                Linker = Linker.assignToTrack(iT, cellData);
                            catch ME
                                
                                %Handle errors
                                fprintf('Error linking at frame %d\n', iT);
                                
                                saveData = input('There was an error linking tracks. Would you like to save the tracked data generated so far (y = yes)?\n','s');
                                if strcmpi(saveData,'y')
                                    tracks = LAPLinker.tracks;
                                    save([saveFN, '.mat'], 'tracks');
                                end
                                rethrow(ME)
                            end
                            
                            %Write movie file (if OutputMovie was set)
                            if opts.OutputMovie
                                
                                if ~exist('vidObj','var') && numel(frameRange) > 1
                                    vidObj = VideoWriter([saveFN, '.avi']); %#ok<TNMLP>
                                    vidObj.FrameRate = 10;
                                    vidObj.Quality = 100;
                                    open(vidObj);
                                    
                                    if ~isempty(opts.SpotChannel)
                                        spotVidObj = VideoWriter([saveFN, 'spots.avi']); %#ok<TNMLP>
                                        spotVidObj.FrameRate = 10;
                                        spotVidObj.Quality = 100;
                                        open(spotVidObj);
                                    end
                                end
                                
                                cellImgOut = CyTracker.makeAnnotatedImage(frame, imgToSegment(:, :, 1), cellLabels, Linker);
                                
                                if numel(frameRange) > 1
                                    vidObj.writeVideo(cellImgOut);
                                else
                                    imwrite(cellImgOut,[saveFN, '.png']);
                                end
                                
                                if ~isempty(opts.SpotChannel)
                                    spotImgOut = CyTracker.makeAnnotatedImage(frame, dotImg, dotLabels, Linker, 'notracks');
                                    spotImgOut = CyTracker.showoverlay(spotImgOut, bwperim(cellLabels), 'Color', [1 0 1]);
                                    
                                    if numel(frameRange) > 1
                                        spotVidObj.writeVideo(spotImgOut);
                                    else
                                        imwrite(spotImgOut,[saveFN, 'spots.png']);
                                    end
                                end
                                
                            end
                        end
                        
                    end
                    
                    frameOffset = frameOffset + reader.sizeT;
                    
                end
                
                %--- END tracking ---%
                Linker = updateMetadata(Linker, 'Timestamps', timestamps, ...
                        'TimestampUnits', tsunit);
                
                %Save the track array
                tracks = Linker.tracks;
                save([saveFN, '.mat'], 'tracks');
                
                %Close video objects
                if exist('vidObj','var')
                    close(vidObj);
                    clear vidObj
                    
                    if ~isempty(opts.SpotChannel)
                        close(spotVidObj);
                        clear spotVidObj
                    end
                end
                
                %Print progress statement
                fprintf('%s %s (series %.0f): Completed.\n', datestr(now), filename{iFile}, iSeries);
            end
            
        end
        
        function cellData = measure(cellLabels, spotLabels, bfReader, iT, pxShift)
            %MEASURE  Get cell data
            %
            %  S = MEASURE(CELL_LABELS, SPOT_LABELS, BFREADER, FRAME,
            %  PXSHIFT)
            
            %Get standard data
            cellData = regionprops(cellLabels, ...
                'Area','Centroid','PixelIdxList','MajorAxisLength',...
                'MinorAxisLength','Orientation');
            
            %Remove non-existing data
            cellData([cellData.Area] ==  0) = [];
            
            %Get intensity data. Names: PropertyChanName
            for iC = 1:bfReader.sizeC
                currImage = bfReader.getPlane(1, iC, iT);
                
                for iCell = 1:numel(cellData)
                    cellData(iCell).(['TotalInt',regexprep(bfReader.channelNames{iC},'[^\w\d]*','')]) = ...
                        sum(currImage(cellData(iCell).PixelIdxList));
                    
                    %Measure spot data
                    if ~isempty(spotLabels)
                        currSpotLabels = false(size(spotLabels));
                        currSpotLabels(cellData(iCell).PixelIdxList) = spotLabels(cellData(iCell).PixelIdxList);
                        spotData = regionprops(currSpotLabels,'Centroid','PixelIdxList');
                        
                        cellData(iCell).NumSpots = numel(spotData);
                        cellData(iCell).NormSpotDist = [];
                        cellData(iCell).MeanSpotInt = zeros(1,numel(spotData));
                        cellData(iCell).SpotCentroid = cat(1, spotData.Centroid);
                        
                        for iSpots = 1:numel(spotData)
                            
                            %Get the normalized distance along the axes
                            diffVec = spotData(iSpots).Centroid - cellData(iCell).Centroid;
                            
                            %Unit vector along cell axis
                            unitVec = [cosd((cellData(iCell).Orientation)), sind((cellData(iCell).Orientation))];
                            
                            %Calculate the projection of the spot along the
                            %cell axis
                            projLen = (diffVec(1) * unitVec(1) + diffVec(2) * unitVec(2))./(cellData(iCell).MajorAxisLength/2);
                                 
                            cellData(iCell).NormSpotDist(iSpots) = projLen;
                            cellData(iCell).MeanSpotInt(iSpots) = mean(currImage(spotData(iSpots).PixelIdxList));
  
                        end
                        
                    end
                end
            end
                        
            %If the image was registered, apply a correction to the
            %PixelIdxList values for tracking code to work correctly
            if ~isempty(pxShift)
                
                cellLabelFinal = zeros(size(cellLabels));
                for iData = 1:numel(cellData)
                    cellLabelFinal(cellData(iData).PixelIdxList) = iData;                    
                end
                
                %Pad the array to ensure that the registered images
                %will not wrap around
                cellLabels_padded = padarray(cellLabelFinal, size(cellLabelFinal), 0, 'both');
                
                cellLabels_padded = CyTracker.shiftimg(cellLabels_padded, pxShift);
                
                regPxList = regionprops(cellLabels_padded, 'PixelIdxList', 'Area');
                
                for iData = 1:numel(cellData)
                    cellData(iData).RegisteredPxInd = regPxList(iData).PixelIdxList;
                end
                
            end
            
        end
        
        function LL = getCellLabels(cellImage, thFactor, segMode, maxCellminDepth, cellAreaLim, varargin)
            %GETCELLLABELS  Segment and label individual cells
            %
            %  L = CyTracker.GETCELLLABELS(I) will segment the cells in image
            %  I, returning a labelled image L. Each value in L should
            %  correspond to an individual cell.
            %
            %  L = CyTracker.GETCELLLABELS(I, M) will use image M to mark
            %  cells. M should be a fluroescent image (e.g. YFP, GFP) that
            %  fully fills the cells.
            
            exportRaw = false;
            if ~isempty(varargin)
                exportRaw = varargin{1};                
            end
                        
            switch lower(segMode)
                
                case 'brightfield'
                    
                    %Pre-process the brightfield image: median filter and
                    %background subtraction
                    cellImageTemp = double(medfilt2(cellImage,[3 3]));
                    
                    bgImage = imopen(cellImageTemp, strel('disk', 40));
                    cellImageTemp = cellImageTemp - bgImage;
                    
                    %Fit the background
                    [nCnts, xBins] = histcounts(cellImageTemp(:), 150);
                    xBins = diff(xBins) + 0.5 * xBins(1:end-1);
                    
                    gf = fit(xBins', nCnts', 'gauss1');
                                        
                    %Compute the threshold level
                    thLvl = gf.b1 + thFactor * gf.c1;
                    
                    %Compute initial cell mask
                    mask = cellImageTemp > thLvl;
                    
                    mask = imfill(mask, 'holes');
                    mask = imopen(mask, strel('disk', 3));
                    mask = imclose(mask, strel('disk', 3));
                    
                    mask = imerode(mask, ones(1));
                    
                    %Separate the cell clumps using watershedding
                    dd = -bwdist(~mask);
                    dd(~mask) = -Inf;
                    dd = imhmin(dd, maxCellminDepth);
                    
                    LL = watershed(dd);
                    mask(LL == 0) = 0;
                    
                    %Tidy up
                    mask = imclearborder(mask);
                    mask = bwmorph(mask,'thicken', 8);
                   
                    %Redraw the masks using cylinders
                    rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
                    
                    %Remove cells which are too small or too large
                    rpCells(([rpCells.Area] < min(cellAreaLim)) | ([rpCells.Area] > max(cellAreaLim))) = [];
                    
                    LL = CyTracker.drawCapsule(size(mask), rpCells);
                    
                case 'fluorescence'
            
                    %Normalize the cellImage
                    cellImage = CyTracker.normalizeimg(cellImage);
                    cellImage = imsharpen(cellImage,'Amount', 2);
                    
                    %Get a threshold
                    [nCnts, binEdges] = histcounts(cellImage(:),150);
                    binCenters = diff(binEdges) + binEdges(1:end-1);
                    
                    %Determine the background intensity level
%                     [~,locs] = findpeaks(nCnts,'Npeaks',1,'sortStr','descend');
                    
%                     gf = fit(binCenters', nCnts', 'Gauss1', 'StartPoint', [nCnts(locs), binCenters(locs), 10000]);
%                     
%                     thLvl = gf.b1 + thFactor * gf.c1;
%                     
                    [maxVal, maxInd] = max(nCnts);
                    thInd = find(nCnts((maxInd + 1): end) < maxVal * thFactor, 1, 'first');
                    thLvl = binCenters(maxInd + thInd);
                    
                    mask = cellImage > thLvl;
                    
                    mask = imopen(mask,strel('disk',3));
                    mask = imclearborder(mask);
                    
                    %mask = activecontour(cellImage,mask);
                    
                    mask = bwareaopen(mask,100);
                    mask = imopen(mask,strel('disk',2));
                    mask = ~bwmorph(~mask, 'clean');
%                     mask = imfill(mask,'holes');
                    
                    dd = -bwdist(~mask);
                    dd(~mask) = -Inf;
                    
                    dd = imhmin(dd, maxCellminDepth);
                    
                    tmpLabels = watershed(dd);
                    
                    mask(tmpLabels == 0) = 0;                    
                    
                    LL = bwareaopen(mask, 100);
                    
%                     %Try to mark the image
%                     markerImg = medfilt2(cellImage,[10 10]);
%                     markerImg = imregionalmax(markerImg,8);
%                     markerImg(~mask) = 0;
%                     markerImg = imdilate(markerImg,strel('disk', 6));
%                     markerImg = imerode(markerImg,strel('disk', 3));
%                     
%                     %Remove regions which are too dark
%                     rptemp = regionprops(markerImg, cellImage,'MeanIntensity','PixelIdxList');
%                     markerTh = median([rptemp.MeanIntensity]) - 0.2 * median([rptemp.MeanIntensity]);
%                     
%                     idxToDelete = 1:numel(rptemp);
%                     idxToDelete([rptemp.MeanIntensity] > markerTh) = [];
%                     
%                     for ii = idxToDelete
%                         markerImg(rptemp(ii).PixelIdxList) = 0;
%                     end
%                     
%                     dd = imcomplement(medfilt2(cellImage,[4 4]));
%                     dd = imimposemin(dd, ~mask | markerImg);
%                     
%                     cellLabels = watershed(dd);
%                     cellLabels = imclearborder(cellLabels);
%                     cellLabels = imopen(cellLabels, strel('disk',6));
%                     
%                     %Redraw the masks using cylinders
%                     rpCells = regionprops(cellLabels,{'Area','PixelIdxList'});
%                     
%                     %Remove cells which are too small or too large
%                     rpCells(([rpCells.Area] < min(cellAreaLim)) | ([rpCells.Area] > max(cellAreaLim))) = [];
%                     
%                     cellLabels = zeros(size(cellLabels));
%                     for ii = 1:numel(rpCells)
%                         cellLabels(rpCells(ii).PixelIdxList) = ii;
%                     end
                                        
                case 'experimental'
                                       
                    %Pre-process the brightfield image: median filter and
                    %background subtraction
                    cellImage = double(cellImage);                    
                   
                    bgImage = imopen(cellImage, strel('disk', 50));
                    cellImageTemp = cellImage - bgImage;
                    cellImageTemp = imgaussfilt(cellImageTemp, 2);
                    
                    %Fit the background
                    [nCnts, xBins] = histcounts(cellImageTemp(:), 150);
                    nCnts = smooth(nCnts, 3);
                    xBins = diff(xBins) + 0.5 * xBins(1:end-1);
                    
                    %Find the peak background
                    [bgPk, bgPkLoc] = max(nCnts);
                    
                    %Find point where counts drop to fraction of peak
                    thLoc = find(nCnts(bgPkLoc:end) <= bgPk * thFactor, 1, 'first');
                    thLoc = thLoc + bgPkLoc;
                    
                    thLvl = xBins(thLoc);
                    
                    %Compute initial cell mask
                    mask = cellImageTemp > thLvl;
                    mask = imopen(mask, strel('disk', 3));
                    mask = imclose(mask, strel('disk', 3));
                    
                    mask = imerode(mask, ones(1));
                    
                    %Separate the cell clumps using watershedding
                    dd = -bwdist(~mask);
                    dd(~mask) = -Inf;
                    dd = imhmin(dd, maxCellminDepth);
                    
                    LL = watershed(dd);
                    mask(LL == 0) = 0;
                    
                    stdBG = std(cellImageTemp(mask == 0));
                    
                    %Tidy up
                    mask = imclearborder(mask);
                    mask = bwareaopen(mask, 100);
                    mask = bwmorph(mask,'thicken', 8);
                    
                    maskCC = bwconncomp(mask);
                    
                    store = zeros(maskCC.NumObjects, 2);

                    for iObj = 1:maskCC.NumObjects
                        
                        meanObj = mean(cellImage(maskCC.PixelIdxList{iObj}));
                        stdObj = std(cellImageTemp(maskCC.PixelIdxList{iObj}));
                        
                        if stdObj < 3 * stdBG
                            mask(maskCC.PixelIdxList{iObj}) = 0;
                        end
                        
                        store(iObj, 1) = meanObj;
                        store(iObj, 2) = stdObj;
                    end
                    %keyboard
%                     
%                     if maskCC.NumObjects <= 15
%                         
%                         %Refine the masks
%                         labels = bwlabel(mask);
%                         labelsRing = imdilate(labels, strel('disk', 2));
%                         labelsRing(mask) = 0;
%                         
%                         cellData = regionprops(labels, cellImageTemp, 'MeanIntensity');
%                         
%                         %For few cells, measure by CNR
%                         noiseData = regionprops(labelsRing, cellImageTemp, 'MeanIntensity');
%                         CNR = [cellData.MeanIntensity] ./ [noiseData.MeanIntensity];
%                         
%                         for iC = 1:numel(cellData)
%                             if CNR(iC) < 1.1
%                                 mask(labels == iC) = 0;
%                             end
%                         end
%                     else
%                         
%                         storeSTD = zeros(1, maskCC.NumObjects);
%                         for iObj = 1:maskCC.NumObjects
%                             storeSTD(iObj) = std(cellImageTemp(maskCC.PixelIdxList{iObj}));
%                         end
%                         
%                         stdThresh = mean(storeSTD) - 1.5 * std(storeSTD);
%                         
%                         for iObj = 1:maskCC.NumObjects
%                             if storeSTD(iObj) < stdThresh
%                                 mask(maskCC.PixelIdxList{iObj}) = 0;
%                             end
%                         end
%                         
%                     end
                    
                    %Identify cells which are too large and try to split
                    %them
                    rpCells = regionprops(mask, {'Area','PixelIdxList'});
                    
                    %Average area
                    medianArea = median([rpCells.Area]);                                        
                    MAD = 1.4826 * median(abs([rpCells.Area] - medianArea));
                    
                    outlierCells = find([rpCells.Area] > (medianArea + 2 * MAD));
                    
                    for iCell = outlierCells
                        
                        currMask = false(size(mask));
                        currMask(rpCells(iCell).PixelIdxList) = true;
                        thLvl = prctile(cellImage(currMask), 40);
                        
                        newMask = cellImage > thLvl;
                        newMask(~currMask) = 0;
                        
                        newMask = imopen(newMask, strel('disk', 3));
                        newMask = imclose(newMask, strel('disk', 3));
                        
                        newMask = imerode(newMask, ones(1));
                        
                        dd = -bwdist(~newMask);
                        dd(~newMask) = -Inf;
                        dd = imhmin(dd, maxCellminDepth);
                        
                        LL = watershed(dd);
                        newMask(LL == 0) = 0;
                        
                        newMask = bwareaopen(newMask, min(cellAreaLim));
                        newMask = bwmorph(newMask,'thicken', 8);
                        
                        %Replace the old masks
                        mask(currMask) = 0;
                        mask(currMask) = newMask(currMask);
                        
                    end
                    
                    if ~exportRaw
                        %Redraw the masks using cylinders
                        rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
                        
                        %Remove cells which are too small or too large
                        rpCells(([rpCells.Area] < min(cellAreaLim)) | ([rpCells.Area] > max(cellAreaLim))) = [];
                        LL = CyTracker.drawCapsule(size(mask), rpCells);
%                         
%                         showoverlay(cellLabels, bwperim(mask));
%                         keyboard
%                         
                        
                    else
                        LL = mask;
                    end
                    
                case 'cy5'
                    
                    %Threshold
                    cellImage = imsharpen(cellImage,'Amount', 2);
                    
                    %Get a threshold
                    [nCnts, binEdges] = histcounts(cellImage(:),linspace(0, double(max(cellImage(:))), 150));
                    binCenters = diff(binEdges) + binEdges(1:end-1);
                    
                    %Find the peak background
                    [bgPk, bgPkLoc] = max(nCnts);
                    
                    %Find point where counts drop to fraction of peak
                    thLoc = find(nCnts(bgPkLoc:end) <= bgPk * thFactor, 1, 'first');
                    thLoc = thLoc + bgPkLoc;
                    
                    thLvl = binCenters(thLoc);
                                     
                    mask = cellImage > thLvl;
                    
                    mask = activecontour(cellImage, mask);
                    
                    
                    dd = -bwdist(~mask);
                    dd(~mask) = -Inf;
                    
                    dd = imhmin(dd, maxCellminDepth);
                    
                    LL = watershed(dd);
                    LL = imclearborder(LL);
                    
                    mask(LL == 0) = 0;
                    %showoverlay(cellImage, bwperim(mask))
                    
                    %Redraw the masks using cylinders
                    rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
                    
                    %Remove cells which are too small or too large
                    rpCells(([rpCells.Area] < min(cellAreaLim)) | ([rpCells.Area] > max(cellAreaLim))) = [];
                    
                    LL = CyTracker.drawCapsule(size(mask), rpCells);
                    
                case 'offset'
                                        
                    cellImage = double(cellImage);
                    
                    %Background-subtract images                    
                    bgImage = imopen(cellImage, strel('disk', 12));
                    cellImageTemp = cellImage - bgImage;
                    
                    cellImageTemp = imgaussfilt(cellImageTemp, 3);
                    
                    %Compute a suitable intensity threshold
                    [nCnts, xBins] = histcounts(cellImageTemp(:), 100);
                    nCnts = smooth(nCnts, 3);
                    xBins = diff(xBins) + xBins(1:end-1);
                    
                    %Find the peak background
                    [bgPk, bgPkLoc] = max(nCnts);
                    
                    %Find point where counts drop to fraction of peak
                    thLoc = find(nCnts(bgPkLoc:end) <= bgPk * thFactor, 1, 'first');
                    thLoc = thLoc + bgPkLoc;
                    
                    thLvl = xBins(thLoc);
                    
                    %Compute initial cell mask
                    mask = cellImageTemp > thLvl;
                    mask = imopen(mask, strel('disk', 3));
                    mask = imclose(mask, strel('disk', 3));
                    
                    mask = bwareaopen(mask, 600);
                    
%                     showoverlay(cellImageTemp, bwperim(mask))
                    
%                     mask = imerode(mask, ones(1));
%                     
%                     %Separate the cell clumps using watershedding
%                     cellImageTemp2 = cellImageTemp;
%                     cellImageTemp2(~mask) = Inf;
%                     localMin = imregionalmin(cellImageTemp2, 8);
%                     localMin(~mask) = 0;
% 
%                     showoverlay(cellImageTemp, localMin)
%                     
                    dd = -bwdist(~mask);
                    dd(~mask) = -Inf;
                    dd = imhmin(dd, maxCellminDepth);
                    
                    LL = watershed(dd);
                    mask(LL == 0) = 0;
                    
%                     stdBG = std(cellImageTemp(mask == 0));
                    
                    %Tidy up
                    mask = imclearborder(mask);
                    mask = bwareaopen(mask, 100);
                    mask = bwmorph(mask,'thicken', 8);
%                     showoverlay(cellImageTemp, bwperim(mask))
                    
                    LL = mask;
%                     keyboard

                otherwise
                    
                    %Call a script. The script must have the following
                    %format:
                    %LABELS = FUNC(cellImage, opts)
                    %Where opts will be a struct containing:
                    %thFactor, segMode, maxCellminDepth, cellAreaLim
                    opts.thFactor = thFactor;
                    opts.segMode = segMode;
                    opts.maxCellminDepth = maxCellminDepth;
                    opts.cellAreaLim = cellAreaLim;
                    
                    LL = eval([segMode, '(cellImage, opts)']);
            end
                        
            if ~any(LL(:))
                warning('No cells detected');              
            end
        end
        
        function spotMask = segmentSpots(imgIn, cellLabels, opts)
            %SEGMENTSPOTS  Finds spots
                    
            %Convert the carboxysome image to double
            spotImg = double(imgIn);
            
            switch lower(opts.SpotSegMode)
                
                case 'localmax'
                    
                    if opts.SpotBgSubtract
                        %Perform a tophat subtraction
                        bgImg = imopen(spotImg, strel('disk', 7));
                        spotImg = spotImg - bgImg;
                    end
                    
                    %Apply a median filter to smooth the image
                    spotImg = medfilt2(spotImg,[2 2]);
                    
                    if islogical(cellLabels)
                        cellLabels = bwlabel(cellLabels);
                    end
                    
                    %Find local maxima in the image using dilation
                    dilCbxImage = imdilate(spotImg,strel('disk',2));
                    dotMask = dilCbxImage == spotImg;
                    
                    spotMask = false(size(spotImg));
                    
                    %Refine the dots by cell intensity
                    for iCell = 1:max(cellLabels(:))
                        
                        currCellMask = cellLabels == iCell;
                        
                        cellBgInt = mean(imgIn(currCellMask));
                        
                        currDotMask = dotMask & currCellMask;
                        currDotMask(imgIn < opts.SpotThreshold * cellBgInt) = 0;
                        
                        spotMask = spotMask | currDotMask;
                    end
     
                case {'dog', 'diffgaussian'}
                    %https://imagej.net/TrackMate_Algorithms#Spot_features_generated_by_the_spot_detectors
                    
                    if opts.SpotErodePx > 0
                        %Hack to remove spots at corner of image
                        cellMask = cellLabels > 0;
                        cellMask = imdilate(cellMask, strel('disk', 1));
                        cellMask = imfill(cellMask, 'holes');
                        cellLabels = imerode(cellMask, strel('disk',opts.SpotErodePx));
                    end
                    
                    sigma1 = (1 / (1 + sqrt(2))) * opts.DoGSpotDiameter;
                    sigma2 = sqrt(2) * sigma1;                    
                    
                    g1 = imgaussfilt(spotImg, sigma1);
                    g2 = imgaussfilt(spotImg, sigma2);
                    
                    dogImg = imcomplement(g2 - g1);
                    
                    %bgVal = mean(dogImg(:));
                    
                    [nCnts, xBins] = histcounts(dogImg(:));
                    xBins = diff(xBins) + xBins(1:end-1);
                    
                    gf = fit(xBins', nCnts', 'gauss1');
                    
                    spotBg = gf.b1 + opts.SpotThreshold .* gf.c1;
                    
                    %Segment the spots
                    spotMask = dogImg > spotBg;
                    spotMask(~cellLabels) = false;
           
                    spotMask = bwareaopen(spotMask, opts.MinSpotArea);

                    dd = -bwdist(~spotMask);
                    
                    LL = watershed(dd);
                    
                    spotMask(LL == 0) = false;

                case 'dogcell'
                    %https://imagej.net/TrackMate_Algorithms#Spot_features_generated_by_the_spot_detectors
                    
                    
                    if opts.SpotErodePx > 0
                        
                        %Hack to remove spots at corner of image
                        cellMask = cellLabels > 0;
                        cellMask = imdilate(cellMask, strel('disk', 1));
                        cellMask = imfill(cellMask, 'holes');
                        cellLabels = imerode(cellMask, strel('disk',opts.SpotErodePx));
                        
                    end
                    
                    %Pre-processing
                    imgFilt2 = imgaussfilt(spotImg, 0.8);
                    
                    imgFilt2 = imtophat(imgFilt2, strel('disk', 3));
                    
                    %imgFilt2 = wdenoise(imgInFilt);
%                     
%                     imshow(imgFilt2, [])
%                     
%                     
%                     keyboard
                    
                    
                    
                    
                    sigma1 = (1 / (1 + sqrt(2))) * opts.DoGSpotDiameter;
                    sigma2 = sqrt(2) * sigma1;                    
                    
                    g1 = imgaussfilt(imgFilt2, sigma1);
                    g2 = imgaussfilt(imgFilt2, sigma2);
                    
                    dogImg = imcomplement(g2 - g1);
                    
                    %bgVal = mean(dogImg(:));
                    
                    [nCnts, xBins] = histcounts(dogImg(:));
                    xBins = diff(xBins) + xBins(1:end-1);
                    
                    gf = fit(xBins', nCnts', 'gauss1');
                    
                    spotBg = gf.b1 + opts.SpotThreshold .* gf.c1;
                    
                    %Segment the spots
                    spotMask = dogImg > spotBg;
                    spotMask(~cellLabels) = false;
           
                    spotMask = bwareaopen(spotMask, opts.MinSpotArea);

                    dd = -bwdist(~spotMask);
                    
                    LL = watershed(dd);
                    
                    spotMask(LL == 0) = false;
                    
                    for iCell = 1:double(max(cellLabels(:)))
                        
                        spotsInCell = spotMask;
                        spotsInCell(cellLabels ~= iCell) = 0;
                        
                        rpSpotsInCell = regionprops(spotsInCell, 'Centroid', 'PixelIdxList');
                        for iSpot = 1:numel(rpSpotsInCell)
                            
                            xInt = spotImg(round(rpSpotsInCell(iSpot).Centroid(2) - 10:rpSpotsInCell(iSpot).Centroid(2) + 10),...
                                round(rpSpotsInCell(iSpot).Centroid(1)));
                            
                            xInt = xInt - mean(xInt);
                            
                            
                            xx = round(rpSpotsInCell(iSpot).Centroid(2) - 10:rpSpotsInCell(iSpot).Centroid(2) + 10);
                            xx = xx - median(xx);
                            
                            [sFit, gof] = fit(xx', xInt, 'gauss1', ...
                                'Upper', [Inf, 3, 4]);
                            
                            figure(99)
                            plot(sFit, xx, xInt)
                            title(['Rsquare = ', num2str(gof.rsquare)])
                            
                            figure(98)
                            currSpotMask = false(size(spotsInCell));
                            currSpotMask(rpSpotsInCell(iSpot).PixelIdxList) = true;
                            
                            
                            showoverlay(spotImg,currSpotMask);
                            keyboard

                        end
                        
                        
%                         cc = bwconncomp(spotsInCell);
                        
%                         %Compute cell statistics
%                         meanIntCell = mean(spotImg(cellLabels == iCell & ~spotsInCell));
%                         stdIntCell = std(spotImg(cellLabels == iCell & ~spotsInCell));
%                         
%                         for iSpot = 1:cc.NumObjects
%                             
%                             
%                             keyboard
%                             currSpotMask = false(size(spotMask));
%                             currSpotMask(cc.PixelIdxList{iSpot}) = true;
%                             
%                             %maxSpotInt = max(max(imgInFilt(currSpotMask)));
%                             maxSpotInt = mean(spotImg(currSpotMask));
%                         
%                             spotCNR = (maxSpotInt - meanIntCell) ./ stdIntCell;
%                             
%                             if spotCNR < opts.SpotCNR
%                                 spotMask(currSpotMask) = false;
%                             end
%                             
%                         end
                        
                        
                    end
                    spotMask = bwareaopen(spotMask, opts.MinSpotArea);
                    
                    if all(~spotMask)
                        keyboard
                        
                    end
                    
                    

                case 'dog2'
                    
                    %Background subtract the spot image
                    spotImgBG = imopen(spotImg, strel('disk', 8));
                    %spotImgBG = medfilt2(spotImg, [10 10]);
                    
                    spotImgBgSub = spotImg - spotImgBG;
                    spotImgBgSub = medfilt2(spotImgBgSub, [3 3]);
                    
                    sigma1 = (1 / (1 + sqrt(2))) * spotDiameter;
                    sigma2 = sqrt(2) * sigma1;
                    
                    g1 = imgaussfilt(spotImgBgSub, sigma1);
                    g2 = imgaussfilt(spotImgBgSub, sigma2);
                    dogImg = g2 - g1;

                    dogImg = medfilt2(dogImg, [3 3]);
                    
                    [nCnts, xBins] = histcounts(dogImg(:));
                    xBins = diff(xBins) - xBins(1:end - 1);
                    [~, maxCnts] = max(nCnts);
                    
                    dogThLvl = xBins(maxCnts) - 9 .* std(dogImg(:));
                    dogMask = dogImg < dogThLvl;
                    
                    %     cellCC = bwconncomp(dogMask);
                    %
                    %     for iCell = 1:cellCC.NumObjects
                    %
                    %         currRingMask = false(size(dogMask));
                    %         currRingMask(cellCC.PixelIdxList{iCell}) = true;
                    %         currRingMask = imdilate(currRingMask, strel('disk', 3));
                    %         currRingMask(cellCC.PixelIdxList{iCell}) = false;
                    %
                    %         meanInt = mean(spotImgBgSub(cellCC.PixelIdxList{iCell}));
                    %
                    %         meanRing = mean(spotImgBgSub(currRingMask));
                    %
                    %         CNR = meanInt / meanRing;
                    %
                    %         if CNR < 1.2
                    %             dogMask(cellCC.PixelIdxList{iCell}) = false;
                    %         end
                    %
                    %     end
                    
                    dogMask(cellLabels == 0) = 0;
                    spotMask = bwareaopen(dogMask, 4);
            end
            
        end
        
        function varargout = showoverlay(img, mask, varargin)
            %SHOWOVERLAY  Overlays a mask on to a base image
            %
            %  SHOWOVERLAY(I, M) will overlay mask M over the image I,
            %  displaying it in a figure window.
            %
            %  C = SHOWOVERLAY(I, M) will return the composited image as a
            %  matrix C. This allows multiple masks to be composited over
            %  the same image. C should be of the same class as the input
            %  image I. However, if the input image I is a double, the
            %  output image C will be normalized to between 0 and 1.
            %
            %  Optional parameters can be supplied to the function to
            %  modify both the color and the transparency of the masks:
            %
            %     'Color' - 1x3 vector specifying the color of the overlay
            %               in normalized RGB coordinates (e.g. [0 0 1] =
            %               blue)
            %
            %     'Opacity' - Value between 0 - 100 specifying the alpha
            %                 level of the overlay. 0 = completely 
            %                 transparent, 100 = completely opaque
            %
            %  Examples:
            %
            %    %Load a test image testImg = imread('cameraman.tif');
            %
            %    %Generate a masked region maskIn = false(size(testImg));
            %    maskIn(50:70,50:200) = true;
            %
            %    %Store the image to a new variable imgOut =
            %    SHOWOVERLAY(testImg, maskIn);
            %
            %    %Generate a second mask maskIn2 = false(size(testImg));
            %    maskIn2(100:180, 50:100) = true;
            %
            %    %Composite and display the second mask onto the same image
            %    %as a magenta layer with 50% opacity
            %    SHOWOVERLAY(imgOut, maskIn2, 'Color', [1 0 1], 'Opacity', 50);
            
            ip = inputParser;
            ip.addParameter('Color',[0 1 0]);
            ip.addParameter('Opacity',100);
            ip.parse(varargin{:});
            
            alpha = ip.Results.Opacity / 100;
            
            %Get the original image class
            imageClass = class(img);
            imageIsInteger = isinteger(img);
            
            %Process the input image
            img = double(img);
            img = img ./ max(img(:));
            
            if size(img,3) == 1
                %Convert into an RGB image
                img = repmat(img, 1, 1, 3);
            elseif size(img,3) == 3
                %Do nothing
            else
                error('showoverlay:InvalidInputImage',...
                    'Expected input to be either a grayscale or RGB image.');
            end
            
            %Process the mask
            mask = double(mask);
            mask = mask ./ max(mask(:));
            
            if size(mask,3) == 1
                %Convert mask into an RGB image
                mask = repmat(mask, 1, 1, 3);
                
                for iC = 1:3
                    mask(:,:,iC) = mask(:,:,iC) .* ip.Results.Color(iC);
                end
            elseif size(mask,3) == 3
                %Do nothing
            else
                error('showoverlay:InvalidMask',...
                    'Expected mask to be either a logical or RGB image.');
            end
            
            %Make the composite image
            replacePx = mask ~= 0;
            img(replacePx) = img(replacePx) .* (1 - alpha) + mask(replacePx) .* alpha;
            
            %Recast the image into the original image class
            if imageIsInteger
                multFactor = double(intmax(imageClass));
            else
                multFactor = 1;
            end
            
            img = img .* multFactor;
            img = cast(img, imageClass);
            
            %Produce the desired outputs
            if nargout == 0
                imshow(img,[])
            else
                varargout = {img};
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
        
        function imgOut = makeAnnotatedImage(iT, baseImage, cellMasks, Linker, varargin)
            %MAKEANNOTATEDIMAGE  Make annotated images
            
            %Normalize the base image
            baseImage = double(baseImage);
            baseImage = baseImage ./ max(baseImage(:));
            
            imgOut = CyTracker.showoverlay(baseImage,...
                bwperim(cellMasks), 'Opacity', 100);
            
            %Write frame number on top right
            imgOut = insertText(imgOut,[size(baseImage,2), 1],iT,...
                'BoxOpacity',0,'TextColor','white','AnchorPoint','RightTop');
            
            %Only plot active tracks
            activeTracks = Linker.activeTrackIDs;            
            for iTrack = activeTracks
                
                if isfield(Linker.tracks.Tracks(iTrack).Data, 'RegCentroid')
                    
                    imgOut = insertText(imgOut, Linker.tracks.Tracks(iTrack).Data.RegCentroid{end}, iTrack,...
                        'BoxOpacity', 0,'TextColor','yellow');
                    
                else
                           try             
                    imgOut = insertText(imgOut, Linker.tracks.Tracks(iTrack).Data.Centroid{end}, iTrack,...
                        'BoxOpacity', 0,'TextColor','yellow');
                           catch
                               keyboard
                           end
                    
                end
                
               
            end
        end
        
        function imgOut = drawCapsule(imgSize, props)
            %DRAWCAPSULE  Draws a capsule at the specified location
            %
            %  L = CyTracker.DRAWCAPSULE(I, RP) will draw capsules given
            %  the Centroid, MajorAxisLength, MinorAxisLength, and
            %  Orientation in RP. RP should be a struct, e.g. generated
            %  using REGIONPROPS.
            
            if numel(imgSize) ~= 2
                error('CyTracker:drawCapsule:InvalidImageSize',...
                    'Image size should be a 1x2 vector.');                
            end
            
            imgOut = zeros(imgSize);
            
            xx = 1:size(imgOut, 2);
            yy = 1:size(imgOut, 1);
            
            [xx, yy] = meshgrid(xx,yy);
            
            for ii = 1:numel(props)
                
                center = props(ii).Centroid;
                theta = props(ii).Orientation/180 * pi;
                cellLen = props(ii).MajorAxisLength;
                cellWidth = props(ii).MinorAxisLength;
                
                rotX = (xx - center(1)) * cos(theta) - (yy - center(2)) * sin(theta);
                rotY = (xx - center(1)) * sin(theta) + (yy - center(2)) * cos(theta);
                
                %Plot the rectangle
                imgOut(abs(rotX) < (cellLen/2 - cellWidth/2) & abs(rotY) < cellWidth/2) = ii;
                
                % %Plot circles on either end
                imgOut(((rotX-(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
                imgOut(((rotX+(cellLen/2 - cellWidth/2)).^2 + rotY.^2) < (cellWidth/2)^2 ) = ii;
                
            end
            
        end
        
        function pxShift = xcorrreg(refImg, movedImg)
            %REGISTERIMG  Register two images using cross-correlation
            %
            %  I = xcorrreg(R, M) registers two images by calculating the
            %  cross-correlation between them. R is the reference or stationary image,
            %  and M is the moved image.
            %
            %  Note: This algorithm only works for translational shifts, and will not
            %  work for rotational shifts or image resizing.
            
            %Compute the cross-correlation of the two images
            crossCorr = ifft2((fft2(refImg) .* conj(fft2(movedImg))));
            
            %Find the location in pixels of the maximum correlation
            [xMax, yMax] = find(crossCorr == max(crossCorr(:)));
            
            %Compute the relative shift in pixels
            Xoffset = fftshift(-size(refImg,1)/2:(size(refImg,1)/2 - 1));
            Yoffset = fftshift(-size(refImg,2)/2:(size(refImg,2)/2 - 1));
            
            pxShift = round([Xoffset(xMax), Yoffset(yMax)]);
            
        end
        
        function corrImg = shiftimg(imgIn, pxShift)
            
            %Translate the moved image to match
            corrImg = circshift(imgIn, pxShift);
            
%             shiftedVal = prctile(imgIn(:), 5);
%             
%             %Delete the shifted regions
%             if pxShift(1) > 0
%                 corrImg(1:pxShift(1),:) = shiftedVal;
%             elseif pxShift(1) < 0
%                 corrImg(end+pxShift(1):end,:) = shiftedVal;
%             end
%             
%             if pxShift(2) > 0
%                 corrImg(:,1:pxShift(2)) = shiftedVal;
%             elseif pxShift(2) < 0
%                 corrImg(:,end+pxShift(2):end) = shiftedVal;
%             end
            
        end
        

    end
    
    methods (Access = private)
        
        function sOut = getOptions(obj)
            %GETOPTIONS  Converts the object properties to a struct
            
            propList = properties(obj);
            for iP = 1:numel(propList)
                sOut.(propList{iP}) = obj.(propList{iP});
            end
        end
        
    end
        
end