classdef DataAnalyzer
    
    properties
        
        tracks
        metadata
        
    end
    
    methods
        
        function obj = DataAnalyzer(varargin)
            
            if isempty(varargin)
                
                [fname, fpath] = uigetfile({'*.mat', 'MAT-file (*.mat)'});
                
                if isequal(fpath, 0)
                    return;                    
                end
            
                filename = fullfile(fpath, fname);
                
            else
                
                filename = varargin{1};
                
            end
            
            data = load(filename);
            
            obj.tracks = data.tracks;
            obj.metadata = data.metadata;
            
            %Fit the data to get the growth rate
            lineFunc = @(x, xdata) x(1) .* xdata + x(2);
            for trackID = 1:numel(obj.tracks)
                
                time = obj.metadata.Timestamps(obj.tracks(trackID).Frame)';
                length = cat(1, obj.tracks(trackID).MajorAxisLength{:});
                
                %Compute logs
                lnLen = log(length);
                
                [fitParams, resnorm] = lsqcurvefit(lineFunc, ...
                    [1, lnLen(1)], time, lnLen);
                
                
                obj.tracks(trackID).GrowthRate = fitParams(1);
                obj.tracks(trackID).GRresnorm = resnorm;
                
            end
            
            
        end
        
        function showtree(obj, trackID)
            %SHOWTREE  Show family tree for specified cell
            
            
            
            
        end        
        
        %--- Tree traversal
        
        function IDout = breadthfirst(obj, rootID)
            %BREADTHFIRST  Perform breadth first traversal
            %
            %  
            
            output = struct('ID', {}, 'X', {}, 'Y', {});
            
            output(1).ID = rootID;
            output(1).X = [0, 0];
            output(1).Y = [obj.tracks(output(1).ID).Frame(1), obj.tracks(output(1).ID).Frame(end)];
            
            queue{1} = rootID;
            
            IDout = [];
            while ~isempty(queue)
                
                IDout(end + 1) = queue{1};
                
                if ~isnan(obj.tracks(queue{1}).DaughterInd)
                    
                    queue{end + 1} = obj.tracks(queue{1}).DaughterInd(1);
                    
                    currIdx = numel(output);
                    newIdx = currIdx + 1;
                    output(newIdx).ID = obj.tracks(queue{1}).DaughterInd(1);
                    
                    %Need to track height as well
                    
                    output(newIdx).X = output(currIdx).X - 
                    output(newIdx).Y = [obj.tracks(output(1).ID).Frame(1), obj.tracks(output(1).ID).Frame(end)];
                    
                    
                    
                    queue{end + 1} = obj.tracks(queue{1}).DaughterInd(2);
                    
                    
                    
                end
                
                queue(1) = [];   
                
 
                
                
            end
            
            
        end
        
        function IDout = preorder(obj, rootRID)
            %PREORDER  Returns record IDs using pre-ordering
            %
            %  L = PREORDER(OBJ, ROOTID) returns a vector L containing the
            %  IDs of tracks having the root node ID. L is preordered: e.g.
            %  the order starts with the root, then down the left tree,
            %  then the right tree.
            
            queue = rootRID;
            IDout = [];
            while ~isempty(queue)
                
                IDout =[IDout, queue(1)]; %#ok<AGROW>
                cid = queue(1);
                queue(1) = [];
                
                queue = [obj.tracks(cid).DaughterInd, queue]; %#ok<AGROW>
                queue(isnan(queue)) = [];
                
            end         
        end
        
        function lineages = getLineages(obj)
            %GETLINEAGES  Returns IDs for lineages in perorder direction
            %
            %  C = GETLINEAGES(OBJ) returns a cell C, with each element in
            %  the cell containing a list of IDs in preorder direction of
            %  the cell lineage. 
            
            %Find all tracks with no mothers (i.e. these existed at the
            %start of the movie)
            rootIDs = 1:numel(obj.tracks);
            rootIDs(~isnan([obj.tracks.MotherID])) = [];
            
            lineages = cell(1, numel(rootIDs));            
            for ii = 1:numel(rootIDs)                
                
                lineages{ii} = preorder(obj, rootIDs(ii));                
                
            end
            
        end
        
        
    end
    
end