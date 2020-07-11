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
    
    properties (Dependent)
        numColonies        
    end
    
    methods
        
        function numColonies = get.numColonies(obj)
            %Return number of colonies
            numColonies = max([obj.Tracks.Colony]);            
        end
        
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
            
            %Look for a TrackArray object and load it
            loadedVars = fieldnames(tmp);
            trackarrayFound = false;
            
            for iData = 1:numel(loadedVars)
                if isa(tmp.(loadedVars{iData}), 'TrackArray')
                    obj = DataAnalyzer.copyObject(tmp.(loadedVars{1}), obj);
                    trackarrayFound = true;                    
                    break;
                end
            end
            
            if ~trackarrayFound
                error('DataAnalyzer:importdata:TrackArrayNotFound', ...
                    'Did not find a TrackArray object.')
            end
            
            %Set the mean delta T
            if ~isempty(obj.FileMetadata.Timestamps)
                obj.MeanDeltaT = mean(diff(obj.FileMetadata.Timestamps));
            end
           
            if ~isempty(obj.FileMetadata.PhysicalPxSize)
                obj.PxSize = obj.FileMetadata.PhysicalPxSize;
                obj.PxUnits = obj.FileMetadata.PhysicalPxSizeUnits;
            end

            obj = analyze(obj);
            
        end
        
        function obj = analyze(obj)
            %ANALYZE  Run analysis on tracks
            
            colonyCount = 0;
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
                
                %--- Colony ID ---%
                if isnan(obj.Tracks(ii).MotherID)
                    colonyCount = colonyCount + 1;
                    obj.Tracks(ii).Colony = colonyCount;
                else
                    motherIndex = findtrack(obj, obj.Tracks(ii).MotherID);
                    obj.Tracks(ii).Colony = obj.Tracks(motherIndex).Colony;
                end
                
            end
            
        end
        
        function plotLineage(obj, rootTrackID, varargin)
            %PLOTLINEAGE  Plot data from a lineage
            %
            %  OBJ = PLOTLINEAGE(OBJ, ROOT) plots the MajorAxisLength of
            %  the track ROOT and all its descendents.
            %
            %  OBj = PLOTLINEAGE(OBJ, ROOT, PROPERTY) plots the property
            %  specified. The property should be a time-series data
            %  fieldname.
            %
            %  Additional arguments can be passed as parameter-value pairs
            %  OBJ = PLOTLINEAGE(OBJ, ..., PARAM, VALUE).
            
            if ~isnumeric(rootTrackID) && ~(numel(rootTrackID) == 1)
                error('DataAnalyzer:plotLineage:InvalidRootID', ...
                    'Root ID is invalid. Expected a single number.');
            end
            
            if ~isempty(varargin)
                propertyToPlot = varargin{1};
            else
                propertyToPlot = 'MajorAxisLength';                
            end
            
            %Get the list of track IDs in level order
            idList = traverse(obj, rootTrackID, 'level');
            isLeft = true;
            
            hold on
            for iTrack = 1:numel(idList)
                
                tt = obj.Tracks(idList(iTrack)).Frames;
                data = [obj.Tracks(idList(iTrack)).Data.(propertyToPlot){:}];
                
                if isLeft
                    plot(tt, data)
                    if iTrack > 1
                        isLeft = false;
                    end
                else
                    plot(tt, data, '--')
                    isLeft = true;
                end
                
            end
            hold off
            ylabel(propertyToPlot)
            xlabel('Frames')            
        end
        
        function plotGrowthRateFit(obj, trackID)
            %PLOTGROWTHRATEFIT  Plot the growth rate fitting parameters
            %
            %  PLOTGROWTHRATEFIT(OBJ, TRACKID) plots the growth rate fit of
            %  the selected track.
            
            xxLine = linspace( obj.Tracks(trackID).Frames(1) * obj.MeanDeltaT, ...
                obj.Tracks(trackID).Frames(end) * obj.MeanDeltaT);
            fitLine = exp(obj.Tracks(trackID).GRFitY) * exp(obj.Tracks(trackID).GrowthRate * xxLine);
            
            %xxLinePlot = xxLine + obj.Tracks(trackID).Frames(1) * obj.MeanDeltaT;
            xxData = obj.Tracks(trackID).Frames * obj.MeanDeltaT;
                        
            plot(xxLine/3600, fitLine, xxData/3600, [obj.Tracks(trackID).Data.MajorAxisLength{:}] * obj.PxSize(1), 'ro');
            
        end
        
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











