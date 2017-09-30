classdef LAPtracker < timeseriesdata
    % LAPTRACKER  Associates tracks using the linear assignment framework
    %     
    %
    %   See also: timeseriesdata
    
    properties (Access = private)
       
        options = struct('MaxLinkDistance',100,...
            'MaxTrackAge',2,...
            'TrackMitosis',true,...
            'MinAgeSinceMitosis',2,...
            'MaxMitosisDistance',30,...
            'MaxMitosisAreaChange',0.3,...
            'LAPSolver','lapjv',...
            'AssociateCellsBy','overlap',...
            'MinMitosisOverlapScore',1/0.8,...
            'MinOverlapScore',0.1);
       
        activeTracks = struct('trackIdx',{},...
            'Age',{},...
            'AgeSinceDivision',{});
        
    end
    
    properties (Access = private, Hidden)
        
        reqProperties = {};
        
        %Changes from false to true whenever a track operation is carried.
        %This property is used to determine whether:
        %  * Genealogy has changed and should be re-calculated
        %  * 
        tracksModified = true;
        
        LAPtrackerVersion = '1.0.0';
        reqCelltrackVersion = '1.0.0';
        
    end
    
    methods %Constructor and settings
        
        function obj = LAPtracker(varargin)
            %Constructs a LAPtracker object
            %
            %  Usage: 
            %
            %  T = LAPtracker(tFrame, S, O) where S is a structure containing
            %  initial track data, and O is an (optional) Parameter/Value
            %  array for options.
            %
            %  T = LAPtracker(O)
            %
            %  T = LAPtracker(tFrame,S)
            
            %Parse the input variables
            if nargin > 1
                
                if ischar(varargin{1})
                    %Must be options only
                    obj = obj.setOptions(varargin{:});
                    
                elseif isnumeric(varargin{1})
                    
                    if numel(varargin) > 2
                        obj = obj.setOptions(varargin{3:end});
                        obj = obj.initializeTracks(varargin{1},varargin{2});
                    else
                        obj = obj.initializeTracks(varargin{1},varargin{2});
                    end
                    
                else
                    error('LAPtracker:frameNumberRequired',...
                        'The first input must be a frame number.');
                    
                end
                
            elseif nargin == 1
                
                error('LAPtracker:insufficientInputs',...
                    'Insufficient number of inputs.');
                
            end
        end
        
        function obj = setOptions(obj,varargin)
            %setOptions  Set options
            %  setOptions(O,'Parameter',value,['Parameter',value...])
            
            obj = obj.setMetadataStruct('options',varargin{:});   
            
        end
        
        function obj = setFileInfo(obj,varargin)
            %setFileInfo  Set file information
            %  setFileInfo(O,'Parameter',value,['Parameter',value...])
            
            obj = obj.setMetadataStruct('fileInfo',varargin{:});
            
        end
        
        function disp(obj)
            %https://www.mathworks.com/help/matlab/matlab_oop/custom-display-interface.html
            fprintf('Cell LAPtracker object\n')
            fprintf('Number of active tracks: %d\n',numel(obj.activeTracks))
            fprintf('Total number of tracks: %d\n',numel(obj))
            
        end
        
        function reqProps = get.reqProperties(obj)
            %Get properties required by the tracking algorithm selected.
                        
            %Update the required fields
            switch lower(obj.options.AssociateCellsBy)
                
                case {'centroid'}
                    
                    if obj.options.TrackMitosis
                        reqProps = {'Centroid','Area'};
                    else
                        reqProps = {'Centroid'};
                    end
                    
                case {'overlap'}
                    
                    reqProps = {'PixelIdxList'};
                    
            end
        end
        
        function version(obj)
            %Prints the version numbers of the LAPtracker and celltrack
            
            fprintf('LAPtracker v%s\n',obj.LAPtrackerVersion)
            fprintf('Celltrack v%s\n',obj.celltrackVersion)
            
        end
    end
    
    methods %Track functions
        
        function obj = initializeTracks(obj,tFrame,structIn)
            %initializeTracks  Initializes the celltrack object
            %
            %  O = O.INITIALIZETRACKS(tFrame,S);
            
            if ~isstruct(structIn)
                error('LAPtracker:initializeTracks:inputNotStruct',...
                    'Expected input to be a structure.');
            end
            
            [~,structIn] = obj.validateInputData(structIn);
            
            %Add parameters to the celltrack object based on the field
            %names of the input structure
            
            paramNames = fieldnames(structIn);
            
            numParams = numel(paramNames);
            
            for iParam = 1:numParams
                %Add properties to track
                defaultValue = nan(1,size(structIn(1).(paramNames{iParam}),2));
                obj = obj.addProperty(paramNames{iParam},true,defaultValue);
            end
            
            obj = obj.addTrackedObject(tFrame,structIn);
        end
        
        function [obj, newTrackIdx] = addTrackedObject(obj,tFrame,inputStruct,didDivide)
            %addTrackedObject  Add a tracked object
            %
            %  This function creates a new track to hold cell data, as well
            %  as updating the activeTrack structure.
            
            %Check if the LAPtracker has been properly initialized
            if numel(obj.pinfo) == 0
                
                obj = initializeTracks(obj,tFrame,inputStruct);
                return
            end
            
            %Validate the inputs
            [~,inputStruct] = obj.validateInputData(inputStruct);
            
            %Add new tracks to the track list
            [obj, newTrackIdx] = obj.addTrack(tFrame,inputStruct);
            
            %Update active tracks
            numNewTracks = numel(newTrackIdx);
            
            for iNT = 1:numNewTracks
                idxNewObject = numel(obj.activeTracks) + 1;
                
                %Update the corresponding trackIdx
                obj.activeTracks(idxNewObject).trackIdx = newTrackIdx(iNT);
                
                %Update the required tracking parameters
                for iP = 1:numel(obj.reqProperties)
                    obj.activeTracks(idxNewObject).(obj.reqProperties{iP}) = inputStruct(iNT).(obj.reqProperties{iP});
                end
                
                %Update the age (0 since it's a new track)
                obj.activeTracks(idxNewObject).Age = 0;
                
                %Check if cell division flag was enabled
                if ~exist('didDivide','var')
                    didDivide = false;
                end
                
                if didDivide
                    obj.activeTracks(idxNewObject).AgeSinceDivision = 0;
                else
                    obj.activeTracks(idxNewObject).AgeSinceDivision = Inf;
                end
            end
            
            obj.tracksModified = true;
            
        end
        
        function obj = ageTrackedObject(obj,trackIdxs)
            %ageTrackedObject  Increment the age of active tracks by 1
            %
            % O = ageTrackedObject(O,indices)

            for ii = trackIdxs
                obj.activeTracks(ii).Age = obj.activeTracks(ii).Age + 1;
            end
            
        end
        
        function obj = removeOldActiveTracks(obj)
            %Removes tracks which have not been updated in awhile. The
            %number of frames allowed is set in the options 'MaxTrackAge'.
            trackAges = [obj.activeTracks.Age];
            
            obj.activeTracks(trackAges > obj.options.MaxTrackAge) = [];
            
        end
             
        function obj = updateTrackedObject(obj,activeTrackIdx,tFrame,inputStruct)
            %updateTrackedObject  Updates celltrack and activeTrack
            
            %Do not allow tracks to be deleted with this function
            if isempty(inputStruct)
                error('Input cannot be empty. To delete a track, use updateTrack.')
            end

            %Convert active track index to cell track index
            trackIdx = obj.activeTracks(activeTrackIdx).trackIdx;
            
            %Update the track with the input
            obj = obj.updateTrack(trackIdx,tFrame,inputStruct);
            
            %If the frame updated is the last one, update active track info
            currTrack = obj.getTrack(trackIdx);
            
            if tFrame >= currTrack.LastFrame
                
                %Update the required properties
                for iRP = 1:numel(obj.reqProperties)
                    obj.activeTracks(activeTrackIdx).(obj.reqProperties{iRP}) = inputStruct.(obj.reqProperties{iRP});
                end
                obj.activeTracks(activeTrackIdx).Age = 0;
                obj.activeTracks(activeTrackIdx).AgeSinceDivision = obj.activeTracks(activeTrackIdx).AgeSinceDivision + 1;
            end
            
            obj.tracksModified = true;
        end

    end
    
    methods %Cell association functions
        
        function costMatrix = makeLinkMatrix_Centroid(obj, newPositions)
            %Calculates the cost matrix for the linear assignment operation
            
            %TODO add options for area/size
            currPositions = cat(1,obj.activeTracks.Centroid);
            
            %Calculate the cost to link based on object distances
            costToLink = obj.calcDistance(currPositions,newPositions);
            costToLink(costToLink > obj.options.MaxLinkDistance) = Inf;
            
            maxCostToLink = max(costToLink(costToLink < Inf));
            
            %Costs for stopping
            stopCost = diag(1.05 * maxCostToLink * ones(1,numel(obj.activeTracks)));
            stopCost(stopCost == 0) = Inf;
            
            %Cost to start a new segment
            segStartCost = diag(1.05 * maxCostToLink * ones(1,size(newPositions,1)));
            segStartCost(segStartCost == 0) = Inf;
            
            %Auxiliary matrix
            auxMatrix = costToLink';
            auxMatrix(auxMatrix < Inf) = min(costToLink(costToLink < Inf));
            
            costMatrix = [costToLink, stopCost; segStartCost, auxMatrix];
            
        end
                
        function costMatrix = makeLinkMatrix_Overlap(obj, newPixelIdxLists)
            %Calculates the cost matrix for the linear assignment operation
            
            %TODO add options for area/size
            currPixelIdxLists = {obj.activeTracks.PixelIdxList}';
            
            %Calculate the cost to link based on object distances
            costToLink = obj.calcOverlap(currPixelIdxLists,newPixelIdxLists);
            costToLink(costToLink < obj.options.MinOverlapScore) = Inf;
            
            maxCostToLink = max(costToLink(costToLink < Inf));
            
            %Costs for stopping
            stopCost = diag(1.05 * maxCostToLink * ones(1,numel(obj.activeTracks)));
            stopCost(stopCost == 0) = Inf;
            
            %Cost to start a new segment
            segStartCost = diag(1.05 * maxCostToLink * ones(1,numel(newPixelIdxLists)));
            segStartCost(segStartCost == 0) = Inf;
            
            %Auxiliary matrix
            auxMatrix = costToLink';
            auxMatrix(auxMatrix < Inf) = min(costToLink(costToLink < Inf));
            
            costMatrix = [costToLink, stopCost; segStartCost, auxMatrix];
        end
        
        function obj = assignToTrack(obj,tFrame,inputStruct)
            %assignToTrack  Runs the assignment algorithm and updates/adds
            %new tracks accordingly.
            
            %Validate the input structure
            [~,inputStruct] = obj.validateInputData(inputStruct);
            
            %Obtain the assignment cost depending on the type of tracking
            %option set
            switch lower(obj.options.AssociateCellsBy)
                
                case 'centroid'
                    
                    %Get the areas and positions of the new detections
                    newPositions = cat(1,inputStruct.Centroid);
                    
                    %Calculate the costMatrix
                    costMat = obj.makeLinkMatrix_Centroid(newPositions);
                    
                    nNewDetections = size(newPositions,1);
                    
                case 'overlap'
                    
                    newPixelIdxLists = {inputStruct.PixelIdxList}';
                    costMat = obj.makeLinkMatrix_Overlap(newPixelIdxLists);
                    nNewDetections = numel(newPixelIdxLists);
            end
                
            %Solve the assignment problem
            switch obj.options.LAPSolver
                case 'munkres'
                    assignments = obj.munkres(costMat);
                    
                case 'lapjv'
                    assignments = obj.lapjv(costMat);
            end
            
            %-----Process the assignments-----%
            
            nExistingTracks = numel(obj.activeTracks);
            
            
            %First set of numbers are associations with the current tracks
            for iM = 1:nExistingTracks
                
                assignedValue = assignments(iM);
                
                if assignedValue > 0 && assignedValue <= nNewDetections
                    
                    %Update the track
                    obj = obj.updateTrackedObject(iM,tFrame,inputStruct(assignedValue));
                    
                else
                    %If the track was not updated, age it by 1                    
                    obj.activeTracks(iM).Age = obj.activeTracks(iM).Age + 1;
                    
                end
            end
            
            %Stop track segments that have not been updated in awhile
            obj = obj.removeOldActiveTracks;
            
            %Second set of assignments are 'start segments'
            for iN = 1:nNewDetections
                
                assignedValue = assignments(nExistingTracks + iN);
                
                if assignedValue > 0 && assignedValue <= nNewDetections
                    
                    %Test for cell division
                    if obj.options.TrackMitosis
                        
                        switch lower(obj.options.AssociateCellsBy)
                            
                            case 'centroid'
                                
                                [isMitosis, motherATidx] = obj.testForMitosis_centroid(inputStruct(assignedValue));
                                
                            case 'overlap'
                                
                                [isMitosis, motherATidx] = obj.testForMitosis_overlap(inputStruct(assignedValue));
                        end
                        
                        if isMitosis
                            
                            motherTrackIdx = obj.activeTracks(motherATidx).trackIdx;
                            
                            %Get the mother track
                            motherTrack = obj.getTrack(motherTrackIdx);
                            
                            %If the "mother cell" was created at the same frame, then it
                            %is not a mitosis event
                            if motherTrack.FirstFrame == tFrame
                                isMitosis = false;
                            end
                        end
                        
                        %If it is a mitosis event:
                        %  (1) Create two new daughter tracks
                        %  (2) Update the motherIdx in the daughter tracks
                        %  (3) 
                        %  (2) Remove the last entry in the mother track
                        %  (3) Stop tracking the mother track (remove from
                        %     activeTracks)
                        %  (4) Update motherIdx and daughterIdx for the
                        %  tracks
                        if isMitosis
                            
                            %Get the mother track index
                            motherTrackIdx = obj.activeTracks(motherATidx).trackIdx;
             
                            %Split the mother track into two
                            [obj, daughterIdx1] = obj.splitTrackedObject(motherTrackIdx,tFrame);
                            
                            %Create a new track with the identified second
                            %daughter track
                            [obj, daughterIdx2] = obj.addTrackedObject(tFrame,inputStruct(assignedValue),1);
                            
                            %Update the MotherIdx of the daughter tracks
                            obj = obj.setMotherIdx(daughterIdx1,motherTrackIdx);
                            obj = obj.setMotherIdx(daughterIdx2,motherTrackIdx);
                                                        
                            %Update daughterIdx in mother track
                            obj = obj.setDaughterIdxs(motherTrackIdx,[daughterIdx1,daughterIdx2]);                            
                            
                            %Remove mother track from activeTracks
                            obj.activeTracks(motherATidx) = [];

                        else %Not mitosis
                            
                            %Create a new track
                            obj = obj.addTrackedObject(tFrame,inputStruct(assignedValue),0);
                                                       
                        end
                        
                    else
                        
                        %Create a new track
                        obj = obj.addTrackedObject(tFrame,inputStruct(assignedValue),0);
                    end
                end
            end
            
            %--- End looping for create new tracks ---%
            
        end
        
        function [obj, newTrackIdx] = splitTrackedObject(obj,trackIdx,tFrameToSplit)
            
            %Split the track
            [obj, newTrackIdx] = obj.splitTrack(trackIdx,tFrameToSplit);
            
            %Add the newly created track to the active tracks list
            newATidx = numel(obj.activeTracks) + 1;
            obj.activeTracks(newATidx).trackIdx = newTrackIdx;
            
            %Update the active track required properties
            obj = obj.updateActiveTracksReqProps(newATidx);

            %Update the age (0 since it's a new track)
            obj.activeTracks(newATidx).Age = 0;
            obj.activeTracks(newATidx).AgeSinceDivision = 0;
        end
                
        function [isMitosis, motherIdx] = testForMitosis_centroid(obj,inputStruct)
            %testForMitosis  Performs tests to see if cell divided
            
            isMitosis = false;  %Default value
            motherIdx = NaN;
            
            %Get particle position and area        
            currPos = inputStruct.Centroid;
            currArea = inputStruct.Area;
            
            validTrackedPos = cat(1,obj.activeTracks.Centroid);
            
            %Exclude cells which were not updated in the current frame
            excludedCells = 1:numel(obj.activeTracks);
            excludedCells = excludedCells([obj.activeTracks.Age] > 0);
            
            for iEx = excludedCells
                validTrackedPos(iEx, :) = [Inf Inf];
            end
            
            %Test to see if there is a particle nearby
            if numel(validTrackedPos) == 0
                return;
            end
            
            %Find the nearest neighbour
            distances = obj.calcDistance(validTrackedPos,currPos);
            distances(distances == 0) = Inf;
            
            distances(distances > obj.options.MaxMitosisDistance) = Inf;
            
            if all(isinf(distances))
                return;
            end
            
            [~,idxNN] = min(distances);
            
            %If nearest neighbour divided recently, then don't allow it to
            %be classified as a division
            if obj.activeTracks(idxNN).AgeSinceDivision < obj.options.MinAgeSinceMitosis
                isMitosis = false;
                return
            end
            
            %Is the nearest neighbour particle of similar size?
            areaNN = obj.activeTracks(idxNN).Area;
            
            if abs(areaNN - currArea)/currArea < obj.options.MaxMitosisAreaChange
                isMitosis = true;
                motherIdx = idxNN;
                return
            end
        end
        
        function [isMitosis, motherIdx] = testForMitosis_overlap(obj,inputStruct)
            %testForMitosis  Performs tests to see if cell divided
            
            isMitosis = false;  %Default value
            motherIdx = NaN;

            %Exclude cells which were not updated in the current frame
            tracksToCheck = 1:numel(obj.activeTracks);
            tracksToCheck([obj.activeTracks.Age] > 0) = [];
            
%             %Test to see if there is a particle nearby
%             if numel(tracksToCheck) == 0
%                 return;
%             end
%             
%             %Need a better way to do this.
%             idxToDelete = [];
%             for ii = 1:numel(tracksToCheck)
%                 
%                 if obj.tracks(obj.activeTracks(tracksToCheck(ii)).trackIdx).Length == 1
%                     
%                     idxToDelete = [idxToDelete, ii];
%                     
%                 end
%             end
            
%TODO! STOPPED HERE
%NEED TO UPDATE THIS TO WORK FOR THE OVERLAP DETECTION

%             tracksToCheck(idxToDelete) = [];
            %Test to see if there is a particle nearby
            if numel(tracksToCheck) == 0
                return;
            end
            
            %For all tracks to check, get the pixel index list of previous
            %frame
            prevPixelList = cell(numel(tracksToCheck),1);
            for iTC = 1:numel(tracksToCheck)
                    prevPixelList{iTC} = obj.track(obj.activeTracks(tracksToCheck(iTC)).trackIdx).PixelIdxList{end - 1};
            end
            
            %Check if new pixel list has significant overlap with previous
            try
                overlapScore = obj.calcOverlap(prevPixelList,{inputStruct.PixelIdxList});
            catch
                keyboard
            end
            [minScore,minIdx] = min(overlapScore);
            
            if minScore < obj.options.MinMitosisOverlapScore
                
                isMitosis = true;
                motherIdx = obj.activeTracks(tracksToCheck(minIdx)).trackIdx;
                
            end
            
        end
    end
    
    methods (Access = private, Hidden = true, Static)   %Assistant functions for cell association
        
        function distancesOut = calcDistance(originalPos, newPos)
            %CALCDISTANCE  Calculates the Euclidean distance between two sets of points
            %
            %Returns N x M matrix where N is the number of original
            %positions and M is the number of new positions
            
            distancesOut = zeros(size(originalPos,1),size(newPos,1));
            
            for iR = 1:size(originalPos,1)
                
                currPos = originalPos(iR,:);
                
                orX = currPos(1);
                orY = currPos(2);
                
                newPosX = newPos(:,1);
                newPosY = newPos(:,2);
                
                distancesOut(iR,:) = sqrt((orX - newPosX).^2 + (orY - newPosY).^2);
                
            end
            
        end
        
        function overlapScore = calcOverlap(originalIdxList,newIdxList)
            %CALCOVERLAP  Calculate overlap
            
            %Overlap score is calculated as the percentage area of the new
            %cell that overlaps with the old cell
            overlapScore = zeros(numel(originalIdxList),numel(newIdxList));
            for iCol = 1:numel(newIdxList)
                for iRow = 1:numel(originalIdxList)
                    overlapScore(iRow,iCol) = sum(ismember(newIdxList{iCol},originalIdxList{iRow}))/numel(newIdxList{iCol});
                end
            end
            
            overlapScore = 1./overlapScore;
        end
        
        function [rowsol, mincost, unassigned_cols] = munkres(costMatrix)
            %MUNKRES  Munkres (Hungarian) linear assignment
            %
            %  [I, C] = MUNKRES(M) returns the column indices I assigned to each row,
            %  and the minimum cost C based on the assignment. The cost of the
            %  assignments are given in matrix M, with workers along the rows and tasks
            %  along the columns. The matrix optimizes the assignment by minimizing the
            %  total cost.
            %
            %  The code can deal with partial assignments, i.e. where M is not a square
            %  matrix. Unassigned rows (workers) will be given a value of 0 in the
            %  output I. [I, C, U] = MUNKRES(M) will give the index of unassigned
            %  columns (tasks) in vector U.
            %
            %  The algorithm attempts to speed up the process in the case where values
            %  of a row or column are all Inf (i.e. impossible link). In that case, the
            %  row or column is excluded from the assignment process; these will be
            %  automatically unassigned in the result.
            %
            %  This code is based on the algorithm described at:
            %  http://csclab.murraystate.edu/bob.pilgrim/445/munkres.html
            
            %Get the size of the matrix
            [nORows, nOCols] = size(costMatrix);
            
            %Check for rows and cols which are all infinity, then remove them
            validRows = ~all(costMatrix == Inf,2);
            validCols = ~all(costMatrix == Inf,1);
            
            nRows = sum(validRows);
            nCols = sum(validCols);
            
            nn = max(nRows,nCols);
            
            if nn == 0
                error('Invalid cost matrix: Cannot be all Inf.')
            elseif any(isnan(costMatrix(:))) || any(costMatrix(:) < 0)
                error('Invalid cost matrix: Expected costs to be all positive numbers.')
            end
            
            %Make a new matrix
            tempCostMatrix = ones(nn) .* (10 * max(max(costMatrix(costMatrix ~= Inf))));
            tempCostMatrix(1:nRows,1:nCols) = costMatrix(validRows,validCols);
            
            tempCostMatrix(tempCostMatrix == Inf) = realmax;
            
            %Get the minimum values of each row
            rowMin = min(tempCostMatrix,[],2);
            
            %Subtract the elements in each row with the corresponding minima
            redMat = bsxfun(@minus,tempCostMatrix,rowMin);
            
            %Mask matrix (0 = not a zero, 1 = starred, 2 = primed)
            mask = zeros(nn);
            
            %Vectors of column and row numbers
            rowNum = 1:nn;
            colNum = rowNum;
            
            %Row and column covers (1 = covered, 0 = uncovered)
            rowCover = zeros(1,nn);
            colCover = rowCover;
            
            %Search for unique zeros (i.e. only one starred zero should exist in each
            %row and column
            for iRow = rowNum(any(redMat,2) == 0)
                for iCol = colNum(any(redMat(iRow,:) == 0))
                    if (redMat(iRow,iCol) == 0 && rowCover(iRow) == 0 && colCover(iCol) == 0)
                        mask(iRow,iCol) = 1;
                        rowCover(iRow) = 1;
                        colCover(iCol) = 1;
                    end
                end
            end
            
            %Clear the row cover
            rowCover(:) = 0;
            
            %The termination condition is when each column has a single starred zero
            while ~all(colCover)
                
                %---Step 4: Prime an uncovered zero---%
                %Find a non-covered zero and prime it.
                %If there is no starred zero in the row containing this primed zero,
                %proceed to step 5.
                %Otherwise, cover this row and uncover the column contianing the
                %starred zero.
                %Continue until there are no uncovered zeros left. Then get the minimum
                %value and proceed to step 6.
                
                stop = false;
                
                %Find an uncovered zero
                for iRow = rowNum( (any(redMat == 0,2))' & (rowCover == 0) )
                    for iCol = colNum(redMat(iRow,:) == 0)
                        
                        if (redMat(iRow,iCol) == 0) && (rowCover(iRow) == 0) && (colCover(iCol) == 0)
                            mask(iRow,iCol) = 2;    %Prime the zero
                            
                            if any(mask(iRow,:) == 1)
                                rowCover(iRow) = 1;
                                colCover(mask(iRow,:) == 1) = 0;
                            else
                                
                                %Step 5: Augment path algorithm
                                currCol = iCol; %Initial search column
                                storePath = [iRow, iCol];
                                
                                %Test if there is a starred zero in the current column
                                while any(mask(:,currCol) == 1)
                                    %Get the (row) index of the starred zero
                                    currRow = find(mask(:,currCol) == 1);
                                    
                                    storePath = [storePath; currRow, currCol];
                                    
                                    %Find the primed zero in this row (there will
                                    %always be one)
                                    currCol = find(mask(currRow,:) == 2);
                                    
                                    storePath = [storePath; currRow, currCol];
                                end
                                
                                %Unstar each starred zero, star each primed zero in the
                                %searched path
                                indMask = sub2ind([nn,nn],storePath(:,1),storePath(:,2));
                                mask(indMask) = mask(indMask) - 1;
                                
                                %Erase all primes
                                mask(mask == 2) = 0;
                                
                                %Uncover all rows
                                rowCover(:) = 0;
                                
                                %Step 3: Cover the columns with stars
                                colCover(:) = any((mask == 1),1);
                                
                                stop = true;
                                break;
                            end
                        end
                        
                        %---Step 6---
                        
                        %Find the minimum uncovered value
                        minUncVal = min(min(redMat(rowCover == 0,colCover== 0)));
                        
                        %Add the value to every element of each covered row
                        redMat(rowCover == 1,:) = redMat(rowCover == 1,:) + minUncVal;
                        
                        %Subtract it from every element of each uncovered column
                        redMat(:,colCover == 0) = redMat(:,colCover == 0) - minUncVal;
                    end
                    
                    if (stop)
                        break;
                    end
                end
                
            end
            
            %Assign the outputs
            rowsol = zeros(nORows,1);
            mincost = 0;
            
            unassigned_cols = 1:nCols;
            
            validRowNum = 1:nORows;
            validRowNum(~validRows) = [];
            
            validColNum = 1:nOCols;
            validColNum(~validCols) = [];
            
            %Only assign valid workers
            for iRow = 1:numel(validRowNum)
                
                assigned_col = colNum(mask(iRow,:) == 1);
                
                %Only assign valid tasks
                if assigned_col > numel(validColNum)
                    %Assign the output
                    rowsol(validRowNum(iRow)) = 0;
                else
                    rowsol(validRowNum(iRow)) = validColNum(assigned_col);
                    
                    %         %Calculate the optimized (minimized) cost
                    mincost = mincost + costMatrix(validRowNum(iRow),validColNum(assigned_col));
                    
                    unassigned_cols(unassigned_cols == assigned_col) = [];
                end
            end
        end
        
        function [rowsol, mincost, v, u, costMat] = lapjv(costMat,resolution)
            % LAPJV  Jonker-Volgenant Algorithm for Linear Assignment Problem.
            %
            % [ROWSOL,COST,v,u,rMat] = LAPJV(COSTMAT, resolution) returns the optimal column indices,
            % ROWSOL, assigned to row in solution, and the minimum COST based on the
            % assignment problem represented by the COSTMAT, where the (i,j)th element
            % represents the cost to assign the jth job to the ith worker.
            % The second optional input can be used to define data resolution to
            % accelerate speed.
            % Other output arguments are:
            % v: dual variables, column reduction numbers.
            % u: dual variables, row reduction numbers.
            % rMat: the reduced cost matrix.
            %
            % For a rectangular (nonsquare) costMat, rowsol is the index vector of the
            % larger dimension assigned to the smaller dimension.
            %
            % [ROWSOL,COST,v,u,rMat] = LAPJV(COSTMAT,resolution) accepts the second
            % input argument as the minimum resolution to differentiate costs between
            % assignments. The default is eps.
            %
            % Known problems: The original algorithm was developed for integer costs.
            % When it is used for real (floating point) costs, sometime the algorithm
            % will take an extreamly long time. In this case, using a reasonable large
            % resolution as the second arguments can significantly increase the
            % solution speed.
            %
            % version 3.0 by Yi Cao at Cranfield University on 10th April 2013
            %
            % This Matlab version is developed based on the orginal C++ version coded
            % by Roy Jonker @ MagicLogic Optimization Inc on 4 September 1996.
            % Reference:
            % R. Jonker and A. Volgenant, "A shortest augmenting path algorithm for
            % dense and spare linear assignment problems", Computing, Vol. 38, pp.
            % 325-340, 1987.
            %
            %
            % Examples
            % Example 1: a 5 x 5 example
            %{
                    [rowsol,cost] = lapjv(magic(5));
                    disp(rowsol); % 3 2 1 5 4
                    disp(cost);   %15
            %}
            % Example 2: 1000 x 1000 random data
            %{
                    n=1000;
                    A=randn(n)./rand(n);
                    tic
                    [a,b]=lapjv(A);
                    toc                 % about 0.5 seconds
            %}
            % Example 3: nonsquare test
            %{
                    n=100;
                    A=1./randn(n);
                    tic
                    [a,b]=lapjv(A);
                    toc % about 0.2 sec
                    A1=[A zeros(n,1)+max(max(A))];
                    tic
                    [a1,b1]=lapjv(A1);
                    toc % about 0.01 sec. The nonsquare one can be done faster!
                    %check results
                    disp(norm(a-a1))
                    disp(b-b)
            %}
            
            if nargin<2
                maxcost=min(1e16,max(max(costMat)));
                resolution=eps(maxcost);
            end
            
            % Prepare working data
            [rdim,cdim] = size(costMat);
            M=min(min(costMat));
            if rdim>cdim
                costMat = costMat';
                [rdim,cdim] = size(costMat);
                swapf=true;
            else
                swapf=false;
            end
            
            dim=cdim;
            costMat = [costMat;2*M+zeros(cdim-rdim,cdim)];
            costMat(costMat~=costMat)=Inf;
            maxcost=max(costMat(costMat<Inf))*dim+1;
            
            if isempty(maxcost)
                maxcost = Inf;
            end
            
            costMat(costMat==Inf)=maxcost;
            % free = zeros(dim,1);      % list of unssigned rows
            % colist = 1:dim;         % list of columns to be scaed in various ways
            % d = zeros(1,dim);       % 'cost-distance' in augmenting path calculation.
            % pred = zeros(dim,1);    % row-predecessor of column in augumenting/alternating path.
            v = zeros(1,dim);         % dual variables, column reduction numbers.
            rowsol = zeros(1,dim)-1;  % column assigned to row in solution
            colsol = zeros(dim,1)-1;  % row assigned to column in solution
            
            numfree=0;
            free = zeros(dim,1);      % list of unssigned rows
            matches = zeros(dim,1);   % counts how many times a row could be assigned.
            
            % The Initilization Phase
            % column reduction
            for j=dim:-1:1 % reverse order gives better results
                % find minimum cost over rows
                [v(j), imin] = min(costMat(:,j));
                if ~matches(imin)
                    % init assignement if minimum row assigned for first time
                    rowsol(imin)=j;
                    colsol(j)=imin;
                elseif v(j)<v(rowsol(imin))
                    j1=rowsol(imin);
                    rowsol(imin)=j;
                    colsol(j)=imin;
                    colsol(j1)=-1;
                else
                    colsol(j)=-1; % row already assigned, column not assigned.
                end
                matches(imin)=matches(imin)+1;
            end
            
            % Reduction transfer from unassigned to assigned rows
            for i=1:dim
                if ~matches(i)      % fill list of unaasigned 'free' rows.
                    numfree=numfree+1;
                    free(numfree)=i;
                else
                    if matches(i) == 1 % transfer reduction from rows that are assigned once.
                        j1 = rowsol(i);
                        x = costMat(i,:)-v;
                        x(j1) = maxcost;
                        v(j1) = v(j1) - min(x);
                    end
                end
            end
            
            % Augmenting reduction of unassigned rows
            loopcnt = 0;
            while loopcnt < 2
                loopcnt = loopcnt + 1;
                % scan all free rows
                % in some cases, a free row may be replaced with another one to be scaed next
                k = 0;
                prvnumfree = numfree;
                numfree = 0;    % start list of rows still free after augmenting row reduction.
                while k < prvnumfree
                    k = k+1;
                    i = free(k);
                    % find minimum and second minimum reduced cost over columns
                    x = costMat(i,:) - v;
                    [umin, j1] = min(x);
                    x(j1) = maxcost;
                    [usubmin, j2] = min(x);
                    i0 = colsol(j1);
                    if usubmin - umin > resolution
                        % change the reduction of the minmum column to increase the
                        % minimum reduced cost in the row to the subminimum.
                        v(j1) = v(j1) - (usubmin - umin);
                    else % minimum and subminimum equal.
                        if i0 > 0 % minimum column j1 is assigned.
                            % swap columns j1 and j2, as j2 may be unassigned.
                            j1 = j2;
                            i0 = colsol(j2);
                        end
                    end
                    % reassign i to j1, possibly de-assigning an i0.
                    rowsol(i) = j1;
                    colsol(j1) = i;
                    if i0 > 0 % ,inimum column j1 assigned easier
                        if usubmin - umin > resolution
                            % put in current k, and go back to that k.
                            % continue augmenting path i - j1 with i0.
                            free(k)=i0;
                            k=k-1;
                        else
                            % no further augmenting reduction possible
                            % store i0 in list of free rows for next phase.
                            numfree = numfree + 1;
                            free(numfree) = i0;
                        end
                    end
                end
            end
            
            % Augmentation Phase
            % augment solution for each free rows
            for f=1:numfree
                freerow = free(f); % start row of augmenting path
                % Dijkstra shortest path algorithm.
                % runs until unassigned column added to shortest path tree.
                d = costMat(freerow,:) - v;
                pred = freerow(1,ones(1,dim));
                collist = 1:dim;
                low = 1; % columns in 1...low-1 are ready, now none.
                up = 1; % columns in low...up-1 are to be scaed for current minimum, now none.
                % columns in up+1...dim are to be considered later to find new minimum,
                % at this stage the list simply contains all columns.
                unassignedfound = false;
                while ~unassignedfound
                    if up == low    % no more columns to be scaned for current minimum.
                        last = low-1;
                        % scan columns for up...dim to find all indices for which new minimum occurs.
                        % store these indices between low+1...up (increasing up).
                        minh = d(collist(up));
                        up = up + 1;
                        for k=up:dim
                            j = collist(k);
                            h = d(j);
                            if h<=minh
                                if h<minh
                                    up = low;
                                    minh = h;
                                end
                                % new index with same minimum, put on index up, and extend list.
                                collist(k) = collist(up);
                                collist(up) = j;
                                up = up +1;
                            end
                        end
                        % check if any of the minimum columns happens to be unassigned.
                        % if so, we have an augmenting path right away.
                        for k=low:up-1
                            if colsol(collist(k)) < 0
                                endofpath = collist(k);
                                unassignedfound = true;
                                break
                            end
                        end
                    end
                    if ~unassignedfound
                        % update 'distances' between freerow and all unscanned columns,
                        % via next scanned column.
                        j1 = collist(low);
                        low=low+1;
                        i = colsol(j1); %line 215
                        x = costMat(i,:)-v;
                        h = x(j1) - minh;
                        xh = x-h;
                        k=up:dim;
                        j=collist(k);
                        vf0 = xh<d;
                        vf = vf0(j);
                        vj = j(vf);
                        vk = k(vf);
                        pred(vj)=i;
                        v2 = xh(vj);
                        d(vj)=v2;
                        vf = v2 == minh; % new column found at same minimum value
                        j2 = vj(vf);
                        k2 = vk(vf);
                        cf = colsol(j2)<0;
                        if any(cf) % unassigned, shortest augmenting path is complete.
                            i2 = find(cf,1);
                            endofpath = j2(i2);
                            unassignedfound = true;
                        else
                            i2 = numel(cf)+1;
                        end
                        % add to list to be scaned right away
                        for k=1:i2-1
                            collist(k2(k)) = collist(up);
                            collist(up) = j2(k);
                            up = up + 1;
                        end
                    end
                end
                % update column prices
                j1=collist(1:last+1);
                v(j1) = v(j1) + d(j1) - minh;
                % reset row and column assignments along the alternating path
                while 1
                    i=pred(endofpath);
                    colsol(endofpath)=i;
                    j1=endofpath;
                    endofpath=rowsol(i);
                    rowsol(i)=j1;
                    if (i==freerow)
                        break
                    end
                end
            end
            
            rowsol = rowsol(1:rdim);
            u=diag(costMat(:,rowsol))-v(rowsol)';
            u=u(1:rdim);
            v=v(1:cdim);
            mincost = sum(u)+sum(v(rowsol));
            costMat=costMat(1:rdim,1:cdim);
            costMat = costMat - u(:,ones(1,cdim)) - v(ones(rdim,1),:);
            
            if swapf
                costMat = costMat';
                t=u';
                u=v';
                v=t;
            end
            
            if mincost>maxcost
                mincost=Inf;
            end
            
        end
        
    end
    
    methods %Analysis functions
        
        function [isValid, inputStruct] = validateInputData(obj,inputStruct)
            %validateInputData  Validates input data structure
            %
            % Checks:
            %    * If this is a new dataset
            %    * input data contains 'Position' and 'Area'
            
            inputFields = fieldnames(inputStruct);
            
            %Make sure that the properties required by the specified
            %tracking algorithm are present
            for iF = 1:numel(obj.reqProperties)
                
                if ~any(strcmp(inputFields,obj.reqProperties{iF}))
                    error('LAPtracker:requiredPropertiesMissing',...
                        'LAPtracker is set to associate cells by %s. Required field %s is missing from input.',...
                        obj.options.AssociateCellsBy,obj.reqProperties{iF})
                end
            
            end
            
%             %!Hack for centroid! Better way would be to rename the original field correctly%
%             if any(strcmp(inputFields,'Centroid')) && ~any(strcmp(inputFields,'Position'))
%                 %If there is a 'centroid' property but no 'position, rename
%                 %'centroid' to 'position'
%                 
%                 [inputStruct.Position] = inputStruct.Centroid;
%                 inputStruct = rmfield(inputStruct,'Centroid');
%                 inputFields = fieldnames(inputStruct);
%             end
%             
%             if ~any(strcmp(inputFields,'Position')) || ~any(strcmp(inputFields,'Area'))
%                 error('LAPtracker:InputMustHavePositionAndArea',...
%                     'Input data must contain Position and Area fields (note capitalization).');
%             end
            
            isValid = true;
            
        end
        
    end
    
    methods (Access = private, Hidden = true)
        
        function obj = setMetadataStruct(obj, structName, varargin)
            %setMetadataStruct   Set the metadata structures
            %
            %  obj = setMetadataStruct(obj, structName, param/val list)
            
            %Validate the input list
            if rem(numel(varargin),2) ~= 0
                error('LAPtracker:setMetadataStruct:inputNotPaired',...
                    'Options input must be Property/Value pairs.')
            end
            
            %Reshape the input into two rows, x number of cols
            inputList = reshape(varargin,2,[]);
            
            optionList = fieldnames(obj.(structName));
            
            %Update the options list
            for iL = 1:size(inputList,2)
                currInputProp = inputList{1,iL};
                if ~any(strcmp(optionList,currInputProp))
                    error('LAPtracker:setMetadataStruct:unknownOption',...
                        '%s is not a valid option',currInputProp);
                end
                obj.(structName).(currInputProp) = inputList{2,iL};
            end
            

            
        end
        
        function obj = updateActiveTracksReqProps(obj, newATidx)
            
            %Get the trackIdx of the active track
            trackIdx = obj.activeTracks(newATidx).trackIdx;

            currTrack = obj.getTrack(trackIdx);
            
            %Update the required property list
            for iP = 1:numel(obj.reqProperties)
                if iscell(currTrack.(obj.reqProperties{iP}))
                    obj.activeTracks(newATidx).(obj.reqProperties{iP}) = currTrack.(obj.reqProperties{iP}){end};
                else
                    obj.activeTracks(newATidx).(obj.reqProperties{iP}) = currTrack.(obj.reqProperties{iP})(end,:);
                end
            end
        end
        
    end
    

end