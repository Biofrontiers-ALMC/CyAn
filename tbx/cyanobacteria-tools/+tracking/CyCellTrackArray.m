classdef CellTrackArray
    %CELLTRACKARRAY  Data class for holding multiple tracks
    %
    %  CELLTRACKARRAY is a data class, designed to hold information for
    %  multiple tracks.
    
    properties (SetAccess = private)
        
        Data
        
        datafields = {};
        datafieldIsTracked
        
    end
    
    methods
        
        function obj = CellTrackArray(varargin)
            
        end
        
        function disp(obj)
            
            fprintf('  celltrack with %d tracks\n',numel(obj));
            fprintf('  Track properties:\n');
            for iP = 1:numel(obj.datafields)
                fprintf('    %s\n',obj.datafields{iP})
            end
                        
        end
        
        function numData = numel(obj)
            numData = numel(obj.Data);
        end
        
        %----- Property functions -----%
        
        function obj = addProperty(obj,propertyName,isTracked,defaultValue)
            
            %Check if current property name exists
            if checkPropertyExists(obj,{propertyName})
                error('celltrack:AddProperty:propertyAlreadyExists',...
                    '"%s" already exists',propertyName);
            end
            
            if ~islogical(isTracked)
                error('Track option must either be "true" or "false"');
            end
            
            if ~exist('defaultValue','var')
                defaultValue = NaN;
            end
            
            %Add to datafields
            obj.datafields{end + 1} = propertyName;  
            obj.datafieldIsTracked(end + 1) = isTracked;
            
            if ~isempty(obj.Data)
                %Add to existing data fields
                for ii = 1:numel(obj)
                    
                    if isTracked
                        
                        currPropLen = numel(obj.Data(ii).(obj.datafields{1}));
                        
                        obj.Data(ii).(propertyName) = cell(currPropLen,1);
                        obj.Data(ii).(propertyName)(1:currPropLen) = {defaultValue};
                        
                    else
                        obj.Data(ii).(propertyName) = {defaultValue};
                        
                    end
                end
            end
            
        end
        
        function valuesOut = getProperty(obj,propertyName)
            
            valuesOut = cell(1,numel(obj));
            
            for iD = 1:numel(obj)
                
                valuesOut{iD} = obj.Data(iD).(propertyName){end};
                
            end
            
        end
        
        function obj = updateProperty(obj,tFrame, trackIdx, propertyName, newValue)

            %Validate the input list
            if ~checkPropertyExists(obj,{propertyName})
                [~, invalidProperty] = checkPropertyExists(obj,inputProperties);
                
                error('cellTrack:AddTrack:PropertyDoesNotExist',...
                    'The following properties do not exist: %s.',invalidProperty);
            end
            
            propertyIdx = find(strcmp(propertyName,obj.datafields));
            
            if obj.datafieldIsTracked(propertyIdx)
                obj.Data(trackIdx).(propertyName){tFrame} = newValue;
            else
                obj.Data(trackIdx).(propertyName) = {newValue};
            end
            
            
        end
        
        %----- Track functions -----%
        
        function [obj, idxToAdd] = addTrack(obj,tFrame,varargin)
            
            %Expect varargin to be in property value pairs
            if rem(numel(varargin),2) ~= 0
                error('celltrack:AddTrack:InputNotInPairs',...
                    'Supplied parameter list must be in Property/Value pairs')
            end
            
            if isempty(obj.datafields)
                error('celltrack:AddTrack:NoPropertiesExist',...
                    'Add a property to track first.')
            end            
            
            %Reshape to two rows (row 1 has property names, row 2 has
            %property values)
            inputList = reshape(varargin,2,[]);
            
            inputProperties = {inputList{1,:}};
            
            %Validate the input list
            if ~checkPropertyExists(obj,inputProperties)
                [~, invalidProperty] = checkPropertyExists(obj,inputProperties);
                
                error('cellTrack:AddTrack:PropertyDoesNotExist',...
                    'The following properties are invalid: %s.',invalidProperty);
            end
            
            if ~checkAllPropertiesSupplied(obj,inputProperties)
                [~,missingProperties] = checkAllPropertiesSupplied(obj,inputProperties);
                                                
                warning('cellTrack:AddTrack:NotAllPropertiesSupplied',...
                    'The following properties are missing: %s.',missingProperties);
            end
            
            %Add a new track to the list
            idxToAdd = numel(obj) + 1;
                        
            %Populate the data structure
            for iP = 1:numel(inputProperties)
                obj.Data(idxToAdd).(inputProperties{iP}) = {inputList{2,iP}};                
            end
            
            %Define the start and end frames
            obj.Data(idxToAdd).StartFrame = tFrame;
            obj.Data(idxToAdd).LastFrame = tFrame;
            
        end
        
        function obj = updateTrack(obj,idxTrack,tFrame,varargin)
            
            if rem(numel(varargin),2) ~= 0
                error('celltrack:UpdateTrack:InputListNotPairs',...
                    'The input list must be in Property/Value pairs.');
            end
            
            inputList = reshape(varargin,2,[]);
            
            inputProperties = {inputList{1,:}};
            
            %Validate the input list
            if ~checkPropertyExists(obj,inputProperties)
                [~, invalidProperty] = checkPropertyExists(obj,inputProperties);
                
                error('cellTrack:AddTrack:PropertyDoesNotExist',...
                    'The following properties are invalid: %s.',invalidProperty);
            end
            
            if ~checkAllPropertiesSupplied(obj,inputProperties)
                [~,missingProperties] = checkAllPropertiesSupplied(obj,inputProperties);
                
                warning('cellTrack:AddTrack:NotAllPropertiesSupplied',...
                    'The following properties are missing: %s.',missingProperties);
            end
            
            if tFrame < 0
                error('Frame number cannot be zero');
            end
            
            if idxTrack < 0 || idxTrack > numel(obj)
                error('Track ID does not exist.')
            end
            
            if tFrame < obj.Data(idxTrack).StartFrame
                %Need to update object to add values between current frame
                %and the start frame
                
                numFramesToAdd = obj.Data(idxTrack).StartFrame - tFrame;
                
                newFields = cell(1,numFramesToAdd);
                
                %Update the tracked fields
                for iP = 1:numel(obj.datafields)
                    if obj.datafieldIsTracked(iP)
                        existingData = obj.Data(idxTrack).(obj.datafields{iP});
                        
                        %Add new data to start of data array
                        obj.Data(idxTrack).(obj.datafields{iP}) = ...
                            {newFields{:}, existingData{:}};
                    end
                end
                
                %Update the start frame
                obj.Data(idxTrack).StartFrame = tFrame;
                
            elseif tFrame > obj.Data(idxTrack).LastFrame
                
                numFramesToAdd = tFrame - (obj.Data(idxTrack).LastFrame + 1);
                newFields = cell(1,numFramesToAdd);
                
                %Update the tracked fields
                for iP = 1:numel(obj.datafields)
                    if obj.datafieldIsTracked(iP)
                        existingData = obj.Data(idxTrack).(obj.datafields{iP});
                        
                        %Add new data to start of data array
                        obj.Data(idxTrack).(obj.datafields{iP}) = ...
                            {existingData{:}, newFields{:}};
                    end
                end
                
                %Update the last frame
                obj.Data(idxTrack).LastFrame = tFrame;
                
            end
            
            idxFrameToUpdate = tFrame - obj.Data(idxTrack).StartFrame + 1;
            
            %Update the track data
            for iIn = 1:size(inputList,2)
                currProperty = inputList{1,iIn};
                currValue = inputList{2, iIn};            

                obj.Data(idxTrack).(currProperty){idxFrameToUpdate} = currValue;
            end
            
        end
        
        function trackOut = getTrack(obj,idxTrack)
            
            %Make sure that the track index exists
            if idxTrack < 0 || idxTrack > numel(obj)
                error('celltrack:GetTrack:trackDoesNotExist',...
                    'Track %d does not exist.',idxTrack);
            end
            
            for iP = 1:numel(obj.datafields)
                currPropertyName = obj.datafields{iP};
                
                if isempty(obj.Data(idxTrack).(currPropertyName))
                    trackOut.(currPropertyName) = [];
                    continue
                end
                
                %Check if the data is numeric (will be false if it's a char
                %or cell)
                
                if isnumeric(obj.Data(idxTrack).(currPropertyName){1})
                    
                    currCell = obj.Data(idxTrack).(currPropertyName);
                    
                    dataSize = size(currCell{1},2);
                    trackOut.(currPropertyName) = nan(numel(currCell),dataSize);
                    for mm = 1:numel(currCell)
                        
                        if ~isempty(currCell{mm})
                            trackOut.(currPropertyName)(mm,:) = currCell{mm};
                        end
                        
                    end
                    
%                    
%                     
%                     %Handle empty cells                    
%                     emptyLocs = cellfun(@isempty,obj.Data(idxTrack).(currPropertyName));
%                     
%                     nonEmptyCell = find(~emptyLocs,1,'first');
%                     nonEmptyCell = obj.Data(idxTrack).(currPropertyName){nonEmptyCell};
%                     
%                     emptyCellIdxs = find(emptyLocs);
%                     
%                     for ii = 1:numel(emptyCellIdxs)
%                         
%                         obj.Data(idxTrack).(currPropertyName){emptyCellIdxs(ii)} = nan(size(nonEmptyCell));
%                         
%                     end
%                     
%                     trackOut.(currPropertyName) = cat(1,obj.Data(idxTrack).(currPropertyName){:});
                else
                    trackOut.(currPropertyName) = obj.Data(idxTrack).(currPropertyName);
                end
            end
            
            trackOut.StartFrame = obj.Data(idxTrack).StartFrame;
            trackOut.LastFrame = obj.Data(idxTrack).LastFrame;
            
        end
        
        %----- Frame functions -----%
        
        function obj = removeFrame(obj,idxTrack,tFrame)
            
            %Make sure tFrame is valid
            if tFrame < obj.Data(idxTrack).StartFrame || tFrame > obj.Data(idxTrack).LastFrame
                error('The requested frame is not within the existing track.')
            end
            
            %Remove the frame from each tracked object property
            frameIdx = tFrame - obj.Data(idxTrack).StartFrame + 1;
            
            for iP = 1:numel(obj.datafields)

                if obj.datafieldIsTracked(iP)
                    
                    obj.Data(idxTrack).(obj.datafields{iP})(frameIdx) = [];
                    
                end
                
            end
            
            %Update the track start or end frame if required
            if tFrame == obj.Data(idxTrack).StartFrame
                
                obj.Data(idxTrack).StartFrame = obj.Data(idxTrack).StartFrame + 1;
                
            elseif tFrame == obj.Data(idxTrack).LastFrame
                
                obj.Data(idxTrack).LastFrame = obj.Data(idxTrack).LastFrame - 1;
                
            end
            
 
            

            
            
        end
                
    end
               
    methods (Access = private)
        
        function [allExist, varargout] = checkPropertyExists(obj,propertyIn)
            %Checks the supplied property (or list of properties) against
            %the allowed datafields to see if the property currently
            %exists.
            
            if ~iscell(propertyIn)
                error('Property list must be a cell')
            end
            
            propertyExists = false(1,numel(propertyIn));
            
            for iP = 1:numel(propertyIn)
                %Check if current property name exists
                if any(strcmp(propertyIn{iP},obj.datafields))
                    propertyExists(iP) = true;
                end
            end
            
            if ~all(propertyExists)
                allExist = false;
                
                %Make a list of properties which do not exist
                varargout{1} = strjoin(propertyIn(~propertyExists),', ');
            else
                allExist = true;
                
                varargout{1} = {};
            end
            
            
        end
        
        function [allSupplied, varargout] = checkAllPropertiesSupplied(obj,propertyIn,varargin)
            %Checks the supplied property (or list of properties) against
            %the allowed datafields to make sure that all the existing
            %datafield names exist.
            
            if ~iscell(propertyIn)
                error('Property list must be a cell')
            end
            
            propertySupplied = false(1,numel(obj.datafields));
            
            for iP = 1:numel(obj.datafields)
                
                if any(strcmp(propertyIn,obj.datafields{iP}))
                    
                    if propertySupplied
                        %Property name is provided twice
                        error('%s is defined more than once',obj.datafields{iP});
                    end
                    
                    propertySupplied(iP) = true;
                end
                
            end
            
            strict = false;
            
            if ~isempty(varargin)
                if strcmpi(varargin{1},'strict')
                    strict = true;
                end
            end
            
            if ~strict
                %Automatically mark untracked fields as supplied
                propertySupplied(~obj.datafieldIsTracked) = true;
            end
            
            
            %Check that the properties are all present            
            if ~all(propertySupplied)
                allSupplied = false;
                
                %Make list of missing properties
                varargout{1} = strjoin(obj.datafields(~propertySupplied),', ');
            else
                allSupplied = true;
                
                varargout{1} = {};
            end
            
        end
        
    end
    
    
end