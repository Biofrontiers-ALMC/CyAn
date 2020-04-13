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
                
                obj = DataAnalyzer.copyObject(tmp.(data{1}), obj);

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












