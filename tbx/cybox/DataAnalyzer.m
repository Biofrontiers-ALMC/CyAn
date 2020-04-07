classdef DataAnalyzer < TrackArray
    %DATAANALYZER  Data analysis for cyanobacteria cells
    %
    %  OBJ = DATAANALYZER creates an empty DataAnalyzer object. Use the
    %  method importdata to load TrackArray data into the object.   
    
    properties
        
        MeanDeltaT = 1;
        PxSize = 1;
        PxUnits = 'unset';
        
    end
    
    methods
                 
        function obj = importdata(obj, filename)
            %IMPORTDATA  Import data into the analyzer object
            %
            %  OBJ = IMPORTDATA(OBJ, FILENAME) imports data from the
            %  MAT-file and carries out additional data cleaning and
            %  processing steps (e.g. assigning colony and generation
            %  numbers, computing growth rate)
            
            if ~exist('filename', 'var')
                
                [filename, pathname] = uigetfile({'*.mat', 'MAT-file'}, ...
                    'Select file(s) to process');
                
                if isequal(filename, 0) || isequal(pathname, 0)
                    %Cancel
                    return;                    
                end
                
                tmp = load(fullfile(pathname, filename));
                
            else
                
                tmp = load(filename);
            end

            data = fieldnames(tmp);
            
            if numel(data) == 1 && isa(tmp.(data{1}), 'TrackArray')
                
                obj = importobj(obj,tmp.(data{1}));

            else
                error('Expected data to be a TrackArray. Other formats not currently supported.')

            end
            
            %Set the mean delta T
            if ~isempty(obj.FileMetadata.Timestamps)
                obj.MeanDeltaT = mean(obj.FileMetadata.Timestamps);
            end
           
            if ~isempty(obj.FileMetadata.PhysicalPxSize)
                obj.PxSize = obj.FileMetadata.PhysicalPxSize;
                obj.PxUnits = obj.FileMetadata.PhysicalPxSizeUnits;
            end
            
            for ii = 1:numel(obj.Tracks)
                
                %--- Calculate Growth Rate ---%
                tt = (obj.Tracks(ii).Frames) * obj.MeanDeltaT;
                
                %Replace empty values (for skipped frames) with NaNs
                len = obj.Tracks(ii).Data.MajorAxisLength;
                
                idxEmpty = find(cellfun(@isempty, len));
                for iC = 1:numel(idxEmpty)
                    len{idxEmpty(iC)} = NaN;
                end
                
                len = cell2mat(len) * obj.FileMetadata.PhysicalPxSize(1);
                
                [obj.Tracks(ii).GrowthRate, obj.Tracks(ii).GRFitY, obj.Tracks(ii).GRFitRes] = ...
                    DataAnalyzer.fitGrowthRate(tt, len);
                
                %--- Calculate generation number ---%
                if isnan(obj.Tracks(ii).MotherID)
                    
                    obj.Tracks(ii).Generation = 1;
                    
                else
                    
                    motherIndex = findtrack(obj, obj.Tracks(ii).MotherID);
                    
                    obj.Tracks(ii).Generation = obj.Tracks(motherIndex).Generation + 1;
                    
                end
                
                
            end
            
        end
        
        
%         function plot(obj, trackID)
%             %Plot
%             
%             %Plot length over time
%             
%             
%             tt = (obj.tracks(trackID).Frame) * meanDeltaT;
%             
%             %Replace empty values (for skipped frames) with NaNs
%             len = obj.tracks(trackID).MajorAxisLength;
%             
%             idxEmpty = find(cellfun(@isempty, len));
%             for iC = 1:numel(idxEmpty)
%                 len{idxEmpty(iC)} = NaN;
%             end
%             
%             plot(tt, cell2mat(len) * obj.metadata.PhysicalPxSize(1));
%             
%             
%         end
%         
%         
%         %--- Tree traversal
%         
%         function IDout = preorder(obj, rootRID)
%             %PREORDER  Returns record IDs using pre-ordering
%             %
%             %  L = PREORDER(OBJ, ROOTID) returns a vector L containing the
%             %  IDs of tracks having the root node ID. L is preordered: e.g.
%             %  the order starts with the root, then down the left tree,
%             %  then the right tree.
%             
%             queue = rootRID;
%             IDout = [];
%             while ~isempty(queue)
%                 
%                 IDout =[IDout, queue(1)]; %#ok<AGROW>
%                 cid = queue(1);
%                 queue(1) = [];
%                 
%                 queue = [obj.tblData(cid).DaughterIDs, queue]; %#ok<AGROW>
%                 queue(isnan(queue)) = [];
%                 
%             end         
%         end
%         
%         function lineages = getLineages(obj)
%             %GETLINEAGES  Returns IDs for lineages in perorder direction
%             %
%             %  C = GETLINEAGES(OBJ) returns a cell C, with each element in
%             %  the cell containing a list of IDs in preorder direction of
%             %  the cell lineage. 
%             
%             %Find all tracks with no mothers (i.e. these existed at the
%             %start of the movie)
%             rootIDs = [obj.tblData.ID];
%             rootIDs(~isnan([obj.tblData.MotherID])) = [];
%             
%             lineages = cell(1, numel(rootIDs));            
%             for ii = 1:numel(rootIDs)                
%                 
%                 lineages{ii} = preorder(obj, rootIDs(ii));                
%                 
%             end
%         end
%         
%         %--- Visualization
%         
%         function varargout = kymogram(obj, ID, varargin)
%             %KYMOGRAM  Generates a kymograph of the specified cell
%             %
%             %  KYMOGRAM(OBJ, ID) generates a kymograph of the cell ID
%             %  specified. A kymograph is a collection of slices of the cell
%             %  along the x-t plane. The cell image is rotated so it is
%             %  horizontal.
%             %
%             %  KYMOGRAM(..., Name, Value) allows additional options to be
%             %  specified as parameter/value pairs. For example, to specify
%             %  that the kymograph be created from the 'GFP' channel, with
%             %  a width of 120 pixels, a slice thickness of 10, and skipping
%             %  every 4 frames:
%             %
%             %  Example:
%             %      kymogram(OBJ, ID, 'Channel', 'GFP', ...
%             %                   'OutputWidth', 120, ...
%             %                   'SliceThickness', 10, ...
%             %                   'FrameSkip', 4)
%             
%             %Default options
%             opts.Channel = 'GFP';
%             opts.OutputWidth = 100;
%             opts.SliceThickness = 20;
%             opts.FrameSkip = 1;
%             opts.Direction = 'down'; %or 'right'
%             opts.CenterOn = 'cell'; %or 'spot'
%             opts.ShowMask = false;
%             opts.ShowCellEdges = true;
%             opts.RescaleImageBy = 1;
%             
%             %Parse varargin
%             options = fieldnames(opts);
%             iArg = 1;
%             while iArg < numel(varargin)
%                 if ismember(varargin{iArg}, options)
%                     opts.(varargin{iArg}) = varargin{iArg + 1};
%                 else
%                     error('iCBXDataAnalyzer:kymogram:InvalidProperty', ...
%                         '%s is not a valid property.', varargin{iArg});
%                 end
%                 iArg = iArg + 2;
%             end
%             
%             %Load the image file
%             bfr = BioformatsImage(obj.tblFileData(obj.tblData(ID).FID).ND2file);
%             
%             %Get the length and time scales
%             lenScale = obj.tblFileData(obj.tblData(ID).FID).PxSize;
%             timeScale = obj.tblFileData(obj.tblData(ID).FID).Timestamps(2) - ...
%                 obj.tblFileData(obj.tblData(ID).FID).Timestamps(1);
%             %keyboard
%             %TODO: Add a scalebar
%             
%             %Initialize storage matrices
%             timeRange = 1:opts.FrameSkip:obj.tblData(ID).TrackLength;
%             finalImage = zeros(numel(timeRange) .* opts.SliceThickness, opts.OutputWidth, 3);
%             
%             cellStart = zeros(1, numel(timeRange));
%             cellEnd = zeros(1, numel(timeRange));            
%             
%             for iT = 1:numel(timeRange)
%                 
%                 %Compute the current frame number
%                 currFrame = timeRange(iT) - 1 + obj.tblData(ID).FirstFrame;
%                 
%                 %Get the image of the plane
%                 I = getPlane(bfr, 1, opts.Channel, currFrame);
%                 
%                 %Store the max intensity as the normalization factor
%                 if iT == 1
%                     Imax = double(max(I(:)));
%                 end
%                 
%                 %Generate the cell mask
%                 mask = false(size(I));
%                 mask(obj.tblData(ID).PixelIdxList{timeRange(iT)}) = true;
% 
%                 %Crop the image down to just the cell
%                 keepRows = any(mask, 2);
%                 keepCols = any(mask, 1);
%                 
%                 I = I(keepRows, keepCols);
%                 mask = mask(keepRows, keepCols);
%                                 
%                 %Normalize image intensity
%                 I = double(I);
%                 I = (I - min(I(:)))./ (Imax - min(I(:)));
%                 
%                 %Make the image RGB
%                 if opts.ShowMask
%                     I = iCBXDataAnalyzer.showoverlay(I, mask);                    
%                 else
%                     I = repmat(I, [1, 1, 3]);
%                 end
%                 
%                 %spotMask = imread(spotMaskFN, iT);
%                 %cropSpotMask = imcrop(spotMask, [centroid(index, 1) - width/2, centroid(index, 2) - width/2, width width]);
%                 %I = showoverlay(I, cropSpotMask, 'color', [1 0 1]);
%                 
%                 %Rotate the image so the cell is horizontal
%                 I = imrotate(I, -obj.tblData(ID).Orientation(timeRange(iT)), 'bicubic', 'crop');
%                                 
%                 %Crop the slice, centered on either the cell or the spot
%                 switch lower(opts.CenterOn)
%                     
%                     case 'cell'
%                                                 
%                         nRows = round(size(I, 1)/2);
%                         I = I((nRows - floor(opts.SliceThickness/2)) + 1:(nRows + ceil(opts.SliceThickness/2)), :, :);
%                         
%                     case 'spot'
%                         
%                         %keyboard
%                         if ~isempty(obj.tblData(ID).SpotCentroid{iT})
%                             
%                             if numel(obj.tblData(ID).SpotCentroid{iT}) > 1
%                                 spotCentroid = obj.tblData(ID).SpotCentroid{iT}(1,:);                                
%                             else
%                                 spotCentroid = obj.tblData(ID).SpotCentroid{iT};
%                             end
%                             
%                             spotMask = zeros(bfr.height, bfr.width);
%                             spotMask(round(spotCentroid(2)), round(spotCentroid(1))) = 100;
%                             spotMask = spotMask(keepRows, keepCols);
%                             spotMask = imrotate(spotMask, -obj.tblData(ID).Orientation(timeRange(iT)), 'bicubic', 'crop');
%                             
%                             spotMaskRow = sum(spotMask, 2);
%                             [~, spotLocY] = max(spotMaskRow);
%                             
%                             %keyboard
%                             I = I(((spotLocY - floor(opts.SliceThickness/2)) + 1):(spotLocY + ceil(opts.SliceThickness/2)), :, :);
%                         else
%                             
%                             nRows = round(size(I, 1)/2);
%                             I = I(((nRows - floor(opts.SliceThickness/2)) + 1):(nRows + ceil(opts.SliceThickness/2)), :, :);
%                             
%                         end
%                         
%                 end
%                 
%                 %Pad I to make it the same size
%                 if size(I, 2) < opts.OutputWidth
%                     
%                     %Compute the difference
%                     padSize = (opts.OutputWidth - size(I, 2))/2;
%                     
%                     %Record the position of the edges of the cell (along
%                     %the cols) in case we need to plot the edges later
%                     cellStart(iT) = floor(padSize);
%                     cellEnd(iT) = floor(padSize) + size(I, 2);
%                     
%                     I = padarray(I, [0, floor(padSize), 0], 'pre');
%                     I = padarray(I, [0, ceil(padSize), 0], 'post');
%                 
%                 elseif size(I, 2) > opts.OutputWidth
%                     
%                     %Image is too wide (handle this)
%                     keyboard
%                
%                 end
%                 
%                 %keyboard
%                 finalImage(((iT - 1) * opts.SliceThickness + 1): (iT * opts.SliceThickness), :, :) = I;
%                 
% %                 imshow(finalImage, [])
% %                 keyboard
%                 
%             end
%             
%             switch lower(opts.Direction)
%                 case 'down'
%                     %It's already pointing downwards
%                     
%                 case 'right'
%                     %Rotate the image
%                     finalImage = rot90(finalImage);
%             end
%             
%             %Rescale image
%             if opts.RescaleImageBy > 1
%                 
%                 finalImage = imresize(finalImage, opts.RescaleImageBy, 'Method', 'bicubic');
%                 cellStart = cellStart .* opts.RescaleImageBy;     
%                 cellEnd = cellEnd .* opts.RescaleImageBy;                
%                 
%             end
%             
%             %Display the image
%             if nargout == 0
%                 imshow(finalImage, []);
%                 
%                 if opts.ShowCellEdges
%                     
%                     %Generate the y-values as half the image width
%                     tt = (opts.SliceThickness .*  opts.RescaleImageBy .* (1:numel(timeRange))) - ((opts.SliceThickness .*  opts.RescaleImageBy)/2);
%                     
%                     switch lower(opts.Direction)
%                         
%                         case 'down'
%                             
%                            
%                             hold on
%                             plot(cellStart, tt, 'w--')
%                             plot(cellEnd, tt, 'w--')
%                             hold off
%                             
% %                             %Insert scalebars
% %                             lenPxs = 1/lenScale;
% %                             lenTime = 1/lenScale;
%                             
%                             
%                         case 'right'
%                                                         
%                             hold on
%                             plot(tt, cellStart, 'w--')
%                             plot(tt, cellEnd, 'w--')
%                             hold off
%                             
%                     end
%                                        
%                 end
%                 
%                 
%             else
%                 varargout{1} = finalImage;
%             end
%             
%         end
%        
    end
    
    methods (Static)
        
        function [growthRate, fitYintercept, fitRes] = fitGrowthRate(tt, cellLengthvTime)
            %FITGROWTHRATE  Calculate the growth rate
            %
            %  The estimated growth rate is fitted to the (natural) log of
            %  the cell length. The fitting uses polyval.
            %
            %  If the cell length data contains NaN values, they will be
            %  removed before fitting. This is because polyval will only
            %  return NaN values if the data is NaN.
            %
            %  Reference:
            %    http://www.sciencedirect.com/science/article/pii/S0092867414014998
            
            logCL = log(cellLengthvTime);
            
            %Remove points where the data is nan - this causes polyfit to
            %always return nans
            delInd = ~isfinite(logCL);
            logCL(delInd) = [];
            tt(delInd) = [];
            
            
            %If there is only 1 point, the code cannot fit a line to it
            if numel(cellLengthvTime) < 2
                growthRate = NaN;
                fitYintercept = NaN;
                fitRes = Inf;
            else
                [fitParams, S] = polyfit(tt,logCL,1);
                
                %The growth rate is the slope
                growthRate = fitParams(1);
                fitYintercept = fitParams(2);
                fitRes = S.normr;
            end
        end
        
        function output = copyObject(input, output)
            C = metaclass(input);
            P = C.Properties;
            for k = 1:length(P)
                if ~P{k}.Dependent
                    output.(P{k}.Name) = input.(P{k}.Name);
                end
            end
        end
        
        
        
    end
    
end












