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

            obj = import(obj, data);
            
        end
        
        function obj = import(obj, data)            
            
            obj.tracks = data.tracks;
            obj.metadata = data.metadata;
                        
            lineFunc = @(x, xdata) x(1) .* xdata + x(2);
            for trackID = 1:numel(obj.tracks)
            
                %--- For tree plotting ---
                
                
                
                %--- Fit the data to get the growth rate ---
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
        
        
        function showtree(obj, rootID)
            %SHOWTREE  Show family tree for specified cell
            
            %Outline:
            %  Need ID list, mothers, and height
            
            [IDs, height] = breadthfirst(DA, 1);

            
                                    
            plot(nodePos(:, 1), nodePos(:, 2), 'o');
        end        
        
        %--- Tree traversal
        
        function [IDlist, height, nodepos] = breadthfirst(obj, rootID)
            %BREADTHFIRST  Perform breadth first traversal
            %
            %  L = BREADTHFIRST(OBJ, ROOTID)
            
            %Pre-allocate a queue
            queue = nan(1, 100);
            queue(1) = rootID;
            
            height = nan(1, 100);
            height(1) = 0;
            
            nodepos = nan(100, 2);
            nodepos(1, :) = [0, obj.tracks(queue(1)).Frame(end)];
            
            %Allocate two pointers
            ptrQcurr = 1;  %Pointer to current position of queue
            ptrQend = 1;  %Pointer to end of the queue
            
            while ~isnan(queue(ptrQcurr))
                
                if ~isnan(obj.tracks(queue(ptrQcurr)).DaughterInd)
                    queue(ptrQend + (1:2)) = obj.tracks(queue(ptrQcurr)).DaughterInd;
                    height(ptrQend + (1:2)) = height(ptrQcurr) + 1;
                                        
                    nodepos(ptrQend + 1, :) = [nodepos(ptrQcurr, 1) - 2^(10 - height(ptrQend + 1)),...
                        obj.tracks(queue(ptrQend + 1)).Frame(end)];
                    nodepos(ptrQend + 2, :) = [nodepos(ptrQcurr, 1) + 2^(10 - height(ptrQend + 2)),...
                        obj.tracks(queue(ptrQend + 2)).Frame(end)];
                    
                    ptrQend = ptrQend + 2;
                end
                
                ptrQcurr = ptrQcurr + 1;
            end
            
            IDlist = queue(~isnan(queue));
            height = height(~isnan(height));
            
            nodepos(any(isnan(nodepos), 2), :) = [];
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