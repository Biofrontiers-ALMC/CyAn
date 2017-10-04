classdef timeseriesdata
    % TIMESERIESDATA  Class to store data as time series
    %   This class implements methods to hold data as time series. 
    %
    %   A single data set, corresponding to a single object, is called
    %   a "track". The tracked data are known as "properties", and their
    %   quantities are "values".
    %
    %   In addition to user-defined properties, each track created also has
    %   FirstFrame, LastFrame and Length. The values for FirstFrame and
    %   LastFrame are stored as frame indices. Currently, the class only
    %   handles data taken at successice equally-spaced points in time.
    %
    %   The class also contains a metadata structure which can be used to
    %   store data about the file used to create the time series data.
    %
    %   *Special behavior: If the input data is 'PixelIdxList', the object
    %   will transpose it to a row. This is to maintain compatibility with
    %   regionprops.
    %
    %   See also: LAPtracker
    
    properties (Access = private)
        
        %Data for each track is stored here. The following properties are
        %always present for each track. Additional properties are added
        %using addProperty.
        %
        %These properties also have their own setter functions.
        tracks = struct('MotherIdx',{},...
            'DaughterIdx',{},...
            'FirstFrame',{},...
            'LastFrame',{},...
            'TrackLen',{});
        
        metadata = struct('Filename','',...
            'OriginalFileLocation','',...
            'Label','',...                  %Used for well location, condition etc. (TBI in a group class)
            'dateCreated',datestr(now),...
            'deltaT',1,...
            'propertyNames',[]);
        
        genealogy
        
    end
    
    properties (Transient)
        
        propertyNames
        
    end
        
    properties (Hidden, SetAccess = private)
        
        tsdVersion = '1.0.0';
        
        pinfo
        
        %pinfo (data property info):
        %  pinfo.(propertyname).isTracked
        %  pinfo.(propertyname).defaultValue
        
    end
    
    methods %Class functions
        
        function obj = timeseriesdata(varargin)
            %Constructs the object

        end
        
        function nOut = numel(obj)
            %Number of stored tracks
            
            nOut = numel(obj.tracks);
        end
        
        function verStr = version(obj)
            %Get object version number
            
            verStr = obj.tsdVersion;
        end
        
        function disp(obj)
            
            fprintf('timeseriesdata with %d tracks\n\n',numel(obj))
            fprintf('Tracks have the following properties:\n')
            if isempty(obj.propertyNames)
                fprintf('[]\n')
            else
                for ii = 1:numel(obj.propertyNames)
                    fprintf('%s\n',obj.propertyNames{ii})
                    
                end
            end
            
        end
    end
    
    methods %Setters and getters
        
        function trackOut = getTrack(obj,trackIdx,varargin)
            %GETTRACK  Get specified track data
            %
            %   S = GETTRACK(obj, trackIndex) gets all data fields for
            %   specified in trackIndex.
            %
            %   S = GETTRACK(obj, trackIndex, propName) gets only the
            %   property specified.
            
            if strcmp(trackIdx,'all')
                trackOut = obj.tracks;
                return;                
            end
            
            
            if isempty(varargin)
                
                %getTrack  Gets specified track
                trackOut = obj.tracks(trackIdx);
                
            else
                
                for ii = 1:numel(varargin)
                    if ~obj.propertyExists(varargin{ii}) || strcmp(varargin{ii},'FirstFrame') || strcmp(varargin{ii},'LastFrame')
                        error('timeseriesdata:getTrack:PropertyDoesNotExist',...
                            '%s does not exist',varargin{ii});
                    end
                    
                    if numel(varargin) == 1
                        %If only one property is requested then return that
                        %value
                        trackOut = obj.tracks(trackIdx).(varargin{ii});
                    else
                        %Otherwise, return a structure
                        trackOut.(varargin{ii}) = obj.tracks(trackIdx).(varargin{ii});
                    end
                end
                
            end
            
        end

        function metadataOut = getMetadata(obj)
            %Read the object metadata
            
            metadataOut = obj.metadata;
            
        end
        
        function obj = setFileInfo(obj,filename,varargin)
            
            if ~isempty(obj.metadata.Filename)
                
                m = input('File information is not empty. Really change data? Y/N [N]:','s');
                
                if strcmpi(m,'y')
                    %Continue
                else
                    error('Aborted setting new file information');
                end
            end
               
            %Split the filename
            [fileLocation, filename] = fileparts(filename);
            
            obj.metadata.OriginalLocation = fileLocation;
            obj.metadata.filename = filename;
            
            if ~isempty(varargin)
                obj.metadata.UserLabel = varargin{:};
            end           
            
        end
        
        function propNames = get.propertyNames(obj)
            %Get list of data property names
            propNames = obj.metadata.propertyNames;
            
        end
        
        function obj = setMotherIdx(obj,trackIdx,motherIdx)
            %Set the motherIdx field
            
            %Validate input
            if trackIdx < 0 || trackIdx > numel(obj.tracks)
                error('timeseriesdata:setMotherIdx:InvalidTrackIndex',...
                    'Track index should be between 1 and %d.',numel(obj.tracks));
            end
            
            obj.tracks(trackIdx).MotherIdx = motherIdx;
            
        end
        
        function obj = setDaughterIdxs(obj,trackIdx,daughterIdxs)
            %Set the daughterIdx field
            
            %Validate input
            if trackIdx < 0 || trackIdx > numel(obj.tracks)
                error('timeseriesdata:setMotherIdx:InvalidTrackIndex',...
                    'Track index should be between 1 and %d.',numel(obj.tracks));
            end
            
            if numel(daughterIdxs) ~= 2
                error('timeseriesdata:setDaughterIdxs:IndexValues',...
                    'There should be exacatly two daugher indices.')
            end
            
            obj.tracks(trackIdx).DaughterIdx = daughterIdxs;
            
        end
        
    end
        
    methods %Data property functions
         
        function obj = addProperty(obj,newField,isTracked,defaultValue,varargin)
            %addProperty  Add a property field to the cell data
            %
            % Usage examples:
            %    obj = obj.addProperty(newFieldName, isTracked,
            %    defaultValue)
            %
            %  If defaultValue is not specified, then defaultValue = NaN,
            %  NaN
            %
            %  Adding multiple properties at once (helps when initializing)
            %    obj = obj.addProperty({newPropertyNames},
            %    logical(isTracked), {defaultValues})
            %
            %  OR
            %    obj = obj.addProperty({newPropertyNames}, isTracked, defaultValues)
            %  isTracked and/or defaultValues can either be the same size as
            %  the newPropertyValues, or they can be of size 1. If they are
            %  size 1, then this value applies to all new properties
            %  created.
            
            %--- Validate the inputs ---%
            if ~islogical(isTracked)
                if all(isTracked == 1 | isTracked == 0)
                    isTracked = logical(isTracked);
                else
                    error('timeseriesdata:addProperty:InvalidInput',...
                        'The isTracked parameter must be logical');
                end
            end
            
            if ischar(newField)
                %if newField is a single entry, make it into a cell to
                %reuse the rest of the code
                newField = {newField};
                defaultValue = {defaultValue};
            end
            
            if ~(numel(isTracked) == 1 || numel(isTracked) == numel(newField))
                error('timeseriesdata:addProperty:InsufficientNumberOfArguments',...
                    'Number of isTracked must equal number of new properties or 1.');
            end
               
            if ~(numel(defaultValue) == 1 || numel(defaultValue) == numel(newField))
                error('timeseriesdata:addProperty:InsufficientNumberOfArguments',...
                    'Number of defaultValues must equal number of new properties or 1.');
            end
            
            %Check if property name(s) are valid variable names and do not
            %currently exist
            for ii = 1:numel(newField)

                %Check if input is a valid MATLAB variable name
                if ~isvarname(newField{ii})
                    error('timeseriesdata:checkNameValid:InvalidVarName',...
                        '%s is an invalid property name. The name should start with a letter.',newField{ii});
                end
                
                if obj.propertyExists(newField{ii})
                    error('timeseriesdata:addProperty:PropertyAlreadyExists',...
                        '%s already exists as a property name',newField{ii});
                end
                
                %Add the new property attributes attributes
                if numel(isTracked) == numel(newField)
                    obj.pinfo.(newField{ii}).isTracked = isTracked(ii);
                else
                    obj.pinfo.(newField{ii}).isTracked = isTracked;
                end
                
                if numel(defaultValue) == numel(newField)
                    obj.pinfo.(newField{ii}).defaultValue = defaultValue{ii};
                else
                    obj.pinfo.(newField{ii}).defaultValue = defaultValue;
                end                
                
                %If tracks already exist, update them to contain the new field
                if numel(obj) > 0
                    
                    %If an input is specified, use it to populate the new
                    %dataset
                    %
                    % if isTracked is true, the accepted inputs are either
                    % (a) defaultValue
                    % (b) a single value to be input to all rows
                    % (c) a single vector with the same number of rows as
                    % frames
                    % (d) a structure with the same number of elements as
                    % tracks and the same number of rows as frames
                    
                    if ~isempty(varargin)
                        newValue = varargin{:};
                    else
                        newValue = obj.pinfo.(newField{ii}).defaultValue;
                    end
                    
                    if isTracked
                        
                        for iT = 1:numel(obj)
                            tracklen = obj.tracks(iT).LastFrame - obj.tracks(iT).FirstFrame + 1;
                            
                            if isnumeric(newValue) && size(newValue,1) == 1
                                obj.tracks(iT).(newField{ii}) = repmat(newValue,tracklen,1);
                                
                            elseif isnumeric(newValue) && size(newValue,1) == tracklen
                                obj.tracks(iT).(newField{ii}) = newValue;
                                
                            elseif ischar(newValue)
                                obj.tracks(iT).(newField{ii}) = cellstr(repmat(newValue,tracklen,1));
                                
                            elseif iscell(newValue)
                                obj.tracks(iT).(newField{ii}) = repmat({newValue},tracklen,1);
                                
                            elseif isstruct(newValue)
                                obj.tracks(iT).(newField{ii}) = newValue(iT).(newField{ii});
                                
                            else
                                
                                error('Error adding new track')
                                
                            end
                            
                        end
                        
                    else
                        [obj.tracks(:).(newField{ii})] = deal(newValue);
                    end
                    
                end
                
            end
            
            %Update the property name list in the metadata
            obj.metadata.propertyNames = fieldnames(obj.pinfo);
        end
        
        function obj = deleteProperty(obj, propName,varargin)
            %DELETEPROPERTY  Delete a data property
            
            %Parse the inputs
            if ~isempty(varargin)
                %If the properties are specified as a list, combine them in
                %a cell array
                propName = [propName, varargin];
            elseif ~iscell(propName)
                %Make the input into a cell to work with the rest of the
                %script
                propName = {propName};                
            end
            
            for ii = 1:numel(propName)
                %Check that property exists
                if ~obj.propertyExists(propName{ii})
                    error('timeseriesdata:deleteProperty:PropertyDoesNotExist',...
                        '%s is not a property name',propName{ii})
                end
                
                if numel(obj.tracks) > 0
                    %Remove the property from the track data
                    obj.tracks = rmfield(obj.tracks,propName{ii});
                end
                
                %Remove the property from the property info list
                obj.pinfo = rmfield(obj.pinfo,propName{ii});
                
                %Remove the name from the list of property names
                obj.metadata.propertyNames(strcmp(obj.metadata.propertyNames,propName{ii})) = [];
            end
        end
        
        function obj = renameProperty(obj,oldPropName, newPropName)
            %RENAMEPROPERTY  Renames a property field
                        
            %Check that the old property exists
            if ~obj.propertyExists(oldPropName)
                error('timeseriesdata:deleteProperty:PropertyDoesNotExist',...
                    '%s is not a property name',oldPropName)
            end
            
            %Check that the new property name is valid
            if ~isvarname(newPropName)
                error('timeseriesdata:renameProperty:InvalidPropertyName',...
                    '%s is not a valid MATLAB property name.',newPropName);
            end
            
            %Add the new property, copying values from the old
            obj = obj.addProperty(newPropName,...
                obj.pinfo.(oldPropName).isTracked,...
                obj.pinfo.(oldPropName).defaultValue);
            
            %If track data exists, copy data over to the new property
            if numel(obj.tracks) > 0
                obj.tracks.(newPropName) = obj.tracks.(oldPropName);
            end
            
            %Delete the old property
            obj = obj.deleteProperty(oldPropName);
            
        end
        
    end
    
    methods %Track functions
        
        function [obj, newTrackIdxs] = addTrack(obj,tFrame,trackDataIn)
            %addTrack  Creates a new track
            %
            %Usage: obj = obj.addTrack(tFrame,trackStruct)
            %
            % trackStruct must be a structure (e.g. compatible with
            % regionprops)
            %    trackStruct(idx).(property)
            
            if ~isnumeric(tFrame)
                error('timeseriesdata:addTrack:timepointNotNumeric',...
                    'Timepoint input must be numeric');
            end
            
            %Validate inputs and add missing required properties
            trackDataIn = obj.validateInputTrack(trackDataIn);            
            trackDataIn = obj.addMissingProperties(trackDataIn,'all');
            
            %Get the name of a tracked property to calculate track length
            for iP = 1:numel(obj.metadata.propertyNames)
                if obj.pinfo.(obj.metadata.propertyNames{iP}).isTracked
                    trackedProp = obj.metadata.propertyNames{iP};
                    break;
                end
            end
            
            %Get the number of new tracks
            nNewTracks = numel(trackDataIn);
            
            %Generate the new track indices
            idxStartAdd = numel(obj) + 1;
            newTrackIdxs = idxStartAdd:(idxStartAdd + nNewTracks - 1);
            
            fields = fieldnames(trackDataIn);
                            
            %Add the new tracks to the data array
            for iNT = 1:nNewTracks

                %Current index for the new track
                currNewIdx = newTrackIdxs(iNT);
                
                currNewDataIn = trackDataIn(iNT);
                
                %Add the new track properties
                for iP = 1:numel(obj.metadata.propertyNames)
                    currProp = obj.metadata.propertyNames{iP};
                    obj.tracks(currNewIdx).(currProp) = currNewDataIn.(currProp);
                end
                
                %Update the static track properties
                obj.tracks(currNewIdx).FirstFrame = tFrame;
                
                if exist('trackedProp','var')
                    if iscell(currNewDataIn.(trackedProp))
                        trackLen = numel(currNewDataIn.(trackedProp));
                    else
                        %Track length is number of rows
                        trackLen = size(currNewDataIn.(trackedProp),1);
                    end
                else
                    trackLen = 1;
                end
                
                obj.tracks(currNewIdx).LastFrame = tFrame + trackLen - 1;
                obj.tracks(currNewIdx).TrackLen = trackLen;
                
                %Check for motherIdx or daughterIdx in the new track data
                if ismember(fields,'MotherIdx')
                    obj.tracks(currNewIdx).MotherIdx = currNewDataIn.MotherIdx;
                else
                    obj.tracks(currNewIdx).MotherIdx = NaN;
                end
                
                if ismember(fields,'DaughterIdx')
                    obj.tracks(currNewIdx).DaughterIdx = currNewDataIn.DaughterIdx;
                else
                    obj.tracks(currNewIdx).DaughterIdx = NaN;
                end
                
            end
        end
        
        function obj = updateTrack(obj,trackIdx,tFrame,trackDataIn)
            %updateTrack  Updates specified track
            %
            %Usage:  S = updateTrack(CT, trackIdx, tFrame, trackDataIn)
            %
            %    trackDataIn is a structure containing the information of
            %    the track
            %
            %To delete a particular frame, input an empty argument for
            %trackDataIn
            %
            %Things to take into account:
            %  If extra frames are required, the default values are used to
            %  append to the track
            %
            %  If the new track to be added is not the same size (i.e.
            %  concatenation fails), the field is converted into a cell
            %  array.
            %
            %  If the new track to be added is not the same type (e.g.
            %  previous entry was a vector, current entry is a char), the
            %  field is converted into a cell array.
            %
            %  If property is untracked, then current value is overwritten.
            
            %Validate inputs
            if isstruct(tFrame)
                %Check that all trackDataIn fields are untracked
                fieldsIn = fieldnames(trackDataIn);
                
                for iP = fieldsIn
                    
                    if obj.pinfo.(iP).isTracked
                        error('timeseriesdata:updateTrack:NoTimeInformation',...
                            'Frame number must be provided');
                    end
                    
                end                
                
            elseif ~isnumeric(tFrame)
                error('timeseriesdata:addTrack:timepointNotNumeric',...
                    'Timepoint input must be numeric');
            end
            
            %Determine where the new track data is to be inserted
            trackToUpdate = obj.getTrack(trackIdx);
            
            %Update the value for each datafield
            propList = obj.metadata.propertyNames;
            
            %Check whether this is an add/append or delete function
            switch isempty(trackDataIn)
                
                case false %Add data to the track
                    
                    %Validate the input data
                    trackDataIn = obj.validateInputTrack(trackDataIn);

                    if tFrame > trackToUpdate.LastFrame
                        %Add new track information to end of last frame
                        
                        trackDataIn = obj.addMissingProperties(trackDataIn);
                        
                        nFramesToAdd = tFrame - trackToUpdate.LastFrame - 1;
                        
                        if nFramesToAdd > 0
                            defaultStruct = obj.makeDefault(nFramesToAdd);
                            %For additional frames, add the default value to the end of
                            %the new track information
                            trackDataIn = obj.mergeStruct(defaultStruct,trackDataIn);
                        end
                        
                        obj.tracks(trackIdx) = obj.mergeStruct(obj.tracks(trackIdx),trackDataIn);
                        obj.tracks(trackIdx).LastFrame = tFrame;
                                                
                    elseif tFrame <= trackToUpdate.LastFrame && tFrame >= trackToUpdate.FirstFrame
                        %For an existing frame, only update the properties
                        %which are specified in the new trackDataIn (this
                        %is useful for updating untracked properties like
                        %motherCell indices)
                        
                        idxToUpdate = tFrame - trackToUpdate.FirstFrame + 1;
                        
                        newProps = fieldnames(trackDataIn);
                        
                        for iP = 1:numel(newProps)
                            
                            if obj.pinfo.(newProps{iP}).isTracked
                                
                                %Handle the different input types
                                if iscell(obj.tracks(trackIdx).(newProps{iP}))
                                    obj.tracks(trackIdx).(newProps{iP}){idxToUpdate} = trackDataIn.(newProps{iP});
                                elseif size(obj.tracks(trackIdx).(newProps{iP}),2) == size(trackDataIn.(newProps{iP}),2)
                                    obj.tracks(trackIdx).(newProps{iP})(idxToUpdate,:) = trackDataIn.(newProps{iP});
                                else
                                    %Convert to cell array then modify
                                    obj.tracks(trackIdx).(newProps{iP}) = mat2cell(obj.tracks(trackIdx).(newProps{iP}),...
                                        ones(size(obj.tracks(trackIdx).(newProps{iP}),1),1),size(obj.tracks(trackIdx).(newProps{iP}),2));
                                    
                                    
                                end
                                
                                obj.tracks(trackIdx).(newProps{iP})(idxToUpdate,:) = trackDataIn.(newProps{iP});
                            else
                                obj.tracks(trackIdx).(newProps{iP}) = trackDataIn.(newProps{iP});
                            end
                        end
                        
                    elseif tFrame < trackToUpdate.FirstFrame
                        
                        trackDataIn = obj.addMissingProperties(trackDataIn);
                        
                        nFramesToAdd = trackToUpdate.FirstFrame - tFrame - 1;
                        
                        %For additional frames, add the default value to the end of
                        %the track information
                        if nFramesToAdd > 0
                            defaultStruct = obj.makeDefault(nFramesToAdd);
                            %For additional frames, add the default value to the end of
                            %the new track information
                            trackDataIn = obj.mergeStruct(trackDataIn,defaultStruct);
                        end
                        
                        %Add information to start of track
                        obj.tracks(trackIdx) = obj.mergeStruct(trackDataIn,obj.tracks(trackIdx));
                        obj.tracks(trackIdx).FirstFrame = tFrame;
                        
                    end
                    
                case true  %New track data is empty, delete the frame
                    
                    idxToDelete = tFrame - obj.tracks(trackIdx).FirstFrame + 1;
                    
                    if idxToDelete < 0 || idxToDelete > obj.tracks(trackIdx).LastFrame
                        error('timeseriesdata:updateTrack:frameDoesNotExist',...
                            'Frame %d does not exist. Frame number should be between %d and %d.',...
                            tFrame,obj.tracks(trackIdx).FirstFrame,obj.tracks(trackIdx).LastFrame);                        
                    end
                    
                    if tFrame < trackToUpdate.LastFrame && tFrame > trackToUpdate.FirstFrame
                        %Replace the tracked values in the deleted frame 
                        %with the defaults
                        for iP = 1:numel(propList)
                            if obj.pinfo.(propList{iP}).isTracked
                                obj.tracks(trackIdx).(propList{iP})(idxToDelete,:) = obj.pinfo.(propList{iP}).defaultValue;
                            end
                        end
                    else
                        %Delete only tracked properties
                        for iP = 1:numel(propList)
                            if obj.pinfo.(propList{iP}).isTracked
                                obj.tracks(trackIdx).(propList{iP})(idxToDelete,:) = [];
                            end
                        end
                        
                        %Update the frame numbers since the first or last 
                        %frame was deleted
                        if tFrame == obj.tracks(trackIdx).FirstFrame
                            obj.tracks(trackIdx).FirstFrame = tFrame + 1;
                            
                        elseif tFrame == obj.tracks(trackIdx).LastFrame
                            obj.tracks(trackIdx).LastFrame = tFrame - 1;
                            
                        end
                    end
            end
            
            %Update track length after any operation
            obj = updateTrackLength(obj,trackIdx);
            
        end
        
        function [obj, newTrackIdx] = splitTrack(obj, trackIdx, tFrameToSplit)
            %splitTrack  Splits a track at the specified frame
            %
            %  splitTrack(obj,trackIdx, tFrameToSplit)
            %
            %When splitting the frame, all untracked properties are copied.
            
            %Make sure that the specified frame exists in the original
            %track
            if tFrameToSplit > obj.tracks(trackIdx).LastFrame || tFrameToSplit <= obj.tracks(trackIdx).FirstFrame
                error('timeseriesdata:splitTrack:invalidFrame',...
                    'Invalid frame number to split (valid values between %d - %d)',...
                    obj.tracks(trackIdx).FirstFrame + 1,obj.tracks(trackIdx).LastFrame)
            end
            
            %Convert frame to index
            frameIdx = tFrameToSplit - obj.tracks(trackIdx).FirstFrame + 1;
            
            %Make a data structure containing the split data
            for iP = 1:numel(obj.metadata.propertyNames)
                currPropName = obj.metadata.propertyNames{iP};
                if obj.pinfo.(currPropName).isTracked
                    newDataStruct.(currPropName) = obj.tracks(trackIdx).(currPropName)(frameIdx:end,:);
                    
                    %Delete frames from original track
                    obj.tracks(trackIdx).(currPropName)(frameIdx:end,:) = [];
                    
                else
                    %Copy the untracked property value
                    newDataStruct.(currPropName) = obj.tracks(trackIdx).(currPropName);
                end
            end
            
            %Add the new track
            [obj, newTrackIdx] = obj.addTrack(tFrameToSplit,newDataStruct);
            
            %Update the old track data
            obj.tracks(trackIdx).LastFrame = tFrameToSplit - 1;
            obj = obj.updateTrackLength(trackIdx);
        end
        
    end
      
    methods %Genealogy functions
        
        function linkedTracks = mapGenealogy(obj,headTrackIdx)
            %mapGenealogy  Maps track genealogy from a given head track
            %
            % Desired output: vector containing all tracks linked from
            % headTrackidx
            %
            % The algorithm works by constructing "track lists", which is a
            % vector of all connecting branches.
            %
            % E.g.[10,51,73];[10,51,74];[10,52]
            
            linkedTracks = {};
            pathsToCheck = {headTrackIdx};
            
            while ~isempty(pathsToCheck)
                
                daughters = obj.tracks(pathsToCheck{1}(end)).DaughterIdx;
                
                if ~isnan(daughters)
                    %If there are daughters, create two tracks representing
                    %the new cell lines
                    pathsToCheck = {[pathsToCheck{1}, daughters(1)]; [pathsToCheck{1}, daughters(2)]; pathsToCheck{2:end}};
                    
                else
                    %If there are no daughters, the tracks are ended. Move
                    %the current linked track to the output list and remove
                    %it from the list of tracks to check
                    linkedTracks = [linkedTracks; pathsToCheck{1}]; %#ok<AGROW>
                    pathsToCheck(1) = [];
                end
            end
        end
                
        function obj = plotGenealogy(obj, genealogyIdx, propertyToPlot)
            
            trackIdxs = obj.genealogy(genealogyIdx).trackIdxs;
            
            for iT = 1:numel(trackIdxs)
                
                plot(obj,trackIdxs,propertyToPlot);
                hold on
            end
            hold off
            
        end
        
    end
    
    methods %Utility and plotting functions
        
        function [trackCnt, timeVec] = getTrackCount(obj)
            %getTrackCount  Count number of existing tracks over time
            
            %First get all the start frames and end frames
            allStartFrames = [obj.tracks.FirstFrame];
            allLastFrames = [obj.tracks.LastFrame];
            
            %Calculates the number of tracks that exist at a given frame
            globalStartFrame = min(allStartFrames);
            globalLastFrame = max(allLastFrames);
            
            %Adjust the start and end frames to index starting from the
            %global start frame
            allStartFrames = allStartFrames - globalStartFrame + 1;
            allLastFrames = allLastFrames - globalStartFrame + 1;
            
            %Calculate total number of frames stored
            numFrames = globalLastFrame - globalStartFrame + 1;
            
            %Initialize an empty vector to hold the cell counts
            trackCnt = zeros(1,numFrames);
            
            %Count tracks
            for iT = 1:numel(allStartFrames)
                
                trackCnt(allStartFrames(iT):allLastFrames(iT)) = ...
                    trackCnt(allStartFrames(iT):allLastFrames(iT)) + 1;
                
            end
            
            timeVec = (globalStartFrame:globalLastFrame) .* obj.metadata.deltaT;
            
        end

        function plot(obj,trackIdx,propertyName)
            %Plots the specified property of the tracks
            
            %Validate the inputs
            if ~propertyExists(obj,propertyName)
                error('timeseriesdata:plot:propertyDoesNotExist',...
                    'Property %s does not exist',propertyName)
            end
            
            %There are two kinds of plots: time on x-axis and data on y, or
            %a position type plot where one column of the track data is
            %plotted vs the other.
            if size(obj.tracks(trackIdx).(propertyName),2) == 1            
                
                %Time based plot
                xTime = (obj.tracks(trackIdx).FirstFrame:obj.tracks(trackIdx).LastFrame)...
                .* obj.metadata.deltaT;
            
                plot(xTime,obj.tracks(trackIdx).(propertyName))
                
            elseif size(obj.tracks(trackIdx).(propertyName),2) == 2
                
                %Position based plot
                plot(obj.tracks(trackIdx).(propertyName)(:,1),obj.tracks(trackIdx).(propertyName)(:,2))
            else
                error('Too many dimensions to plot')
            end
            
            
        end
        
        function [meanOut, tt, joinedMatrix] = timemean(obj,propertyName)
            %Calculates the time-dependent mean of the specified property 
            %for all the tracks
            
             %Validate the inputs
            if ~propertyExists(obj,propertyName)
                error('timeseriesdata:timemean:propertyDoesNotExist',...
                    'Property %s does not exist',propertyName)
            end
            
            if ~(obj.pinfo.(propertyName).isTracked)
                error('timeseriesdata:timemean:propertyNotTracked',...
                    'Property %s is not time tracked. To calculate the mean, use mean.',propertyName)
            end
            
            %Get the smallest first frame number and the largest last frame
            %number for all the tracks
            minFirstFrame = min([obj.tracks.FirstFrame]);
            maxLastFrame = max([obj.tracks.LastFrame]);            
            
            %Make the large storage matrix
            joinedMatrix = nan(numel(obj),maxLastFrame - minFirstFrame + 1);
            
            %Bin the data
            for iRow = 1:numel(obj)
                
                %Calculate the column index to append data to
                startColIdx = (obj.tracks(iRow).FirstFrame - minFirstFrame) + 1;
                
                trackLen = obj.tracks(iRow).LastFrame - obj.tracks(iRow).FirstFrame + 1;
                
                joinedMatrix(iRow,startColIdx:startColIdx+trackLen - 1) = obj.tracks(iRow).(propertyName);

            end
            
            meanOut = mean(joinedMatrix,1,'omitnan');
            tt = (minFirstFrame:maxLastFrame) * obj.metadata.deltaT;
        end
        
    end
    
    methods %Data import and export functions
        
        function obj = importdata(obj,oldObj)
            %IMPORTDATA  Import data from old versions of the class
            %
            %  obj = IMPORTDATA(obj, trackdata) where trackdata is a struct
            %  containing exported track data from a previous version.
            %
            %  Old versions supported: v0.9.0
            
            %Check which past version the data is in
            
            switch oldObj.version
                
                case 'v0.9.0'
                    
                    %Track properties are:
                    % (struct) Data - containing track data
                    % (cell) datafields - containing name of data properties
                    % (double) datafieldIsTracked - isTracked
                    % (char) version - version number
                    
                    %Add data properties (default values are now NaN)
                    obj = obj.addProperty(oldObj.datafields,oldObj.datafieldIsTracked,NaN);
                    
                    %Populate the track data with the old dataset
                    nTracks = numel(oldObj.Data);
                    
                    for idxOldTrack = 1:nTracks
                        
                        %Convert data from cell array to a structure
                        trackOut = [];
                        for iProp = 1:numel(obj.metadata.propertyNames)
                            
                            currPropertyName = obj.metadata.propertyNames{iProp};
                            
                            %Check if the first data entry is numeric (will
                            %be false if it is a char or cell)
                            if isnumeric(oldObj.Data(idxOldTrack).(currPropertyName){1})
                                
                                currCell = oldObj.Data(idxOldTrack).(currPropertyName);
                                
                                %If the data is numeric, convert the data
                                %into a vector
                                dataSize = size(currCell{1},2);
                                trackOut.(currPropertyName) = nan(numel(currCell),dataSize);
                                for mm = 1:numel(currCell)
                                    
                                    if ~isempty(currCell{mm})
                                        trackOut.(currPropertyName)(mm,:) = currCell{mm};
                                    end
                                    
                                end
                                
                            elseif iscell((oldObj.Data(idxOldTrack).(currPropertyName){1}))
                                %If the data is a cell array, store the
                                %contents as a cell array (i.e. remove the
                                %extra cell wrapping around it).
                                %
                                %In the old data format, values like the
                                %PixelIdxList would store values as a cell
                                %array of cell arrays:
                                %  data =
                                %  {{[pixelIdxList1]},{[pixelIdxList2]}}.
                                %
                                %This is too many levels of cells, so
                                %convert it to:
                                %  data = {[pixelIdxList1],
                                %  [pixelIdxList2]}
                                currCell = oldObj.Data(idxOldTrack).(currPropertyName);
                                
                                for mm = 1:numel(currCell)
                                    
                                    if ~isempty(currCell{mm})
                                        trackOut.(currPropertyName)(mm,:) = oldObj.Data(idxOldTrack).(currPropertyName){:};
                                    end
                                    
                                end
                            end
                            
                        end
                        trackOut.StartFrame = oldObj.Data(idxOldTrack).StartFrame;
                        trackOut.LastFrame = oldObj.Data(idxOldTrack).LastFrame;
                        trackOut.TrackLen = trackOut.LastFrame - trackOut.StartFrame + 1;
                        
                        %Store data
                        if isempty(obj.tracks)
                            obj.tracks = trackOut;
                        else
                            idxNewTrack = numel(obj.tracks) + 1;
                            obj.tracks(idxNewTrack) = trackOut;
                        end
                        
                    end
            end
        end

        function exportData(obj,filename,varargin)
            
            %Parse additional options if set
            forceSave = false;  %Automatically overwrite data if it exists
            if ~isempty(varargin)
                
                for ii = 1:numel(varargin)
                    
                    if strcmpi(varargin{ii},'silent')
                        forceSave = true;
                    end
                    
                end                
            end
                        
            %Determine the type of data to export based on the file
            %extension
            [~,~,ext] = fileparts(filename);
            if isempty(ext)
                ext = '.mat';
            end
            
            %Prompt for overwrite if file exists
            if exist(filename,'file') && ~forceSave
                
                m = input('File exists. Overwrite? Y/N [Y]:','s');
                if strcmpi(m,'y')
                    %Continue
                else
                   error('%s exists. Specify a new filename.',filename); 
                end
                
            end
            
            switch lower(ext)
                
                case '.csv'  %Save data as a CSV file
                    
                    %Open the file
                    fid = fopen(filename,'w');
                    
                    if fid == -1
                        error('timeseriesdata:exportData:ErrorOpeningFile',...
                            'Error opening file for writing.')                        
                    end
                    
                    %Write metadata
                    fprintf(fid,'Label: %s\n',obj.metadata.Label);
                    fprintf(fid,'Filename: %s\n',obj.metadata.Filename);
                    fprintf(fid,'Original file location: %s\n',obj.metadata.OriginalLocation);
                    
                    fprintf(fid,'\nDate created: %s\n',obj.metadata.dateCreated);
                    fprintf(fid,'Delta T: %f\n',obj.metadata.deltaT);
                    
                    
                    %--- Write track data ---%
                    %Write the column headers (aka property names)
                    headerStr = ['TrackID, FirstFrame, LastFrame',sprintf(', %s',obj.metadata.propertyNames{:})];
                                  
                    fprintf(fid,'%s\n',headerStr);
                    
                    %Format the track data for a single row as a string.
                    %This works by going through each property (column) and
                    %writing that number into the string. 
                    %
                    %For properties which are not tracked over time, only
                    %need to do this on the first row.
                    for iT = 1:numel(obj.tracks)
                        
                        nDataRows = obj.tracks(iT).TrackLen;
                        
                        for iData = 1:nDataRows
                            
                            %Write the track information only on the first
                            %row
                            if iData == 1
                                rowStr = [int2str(iT),', ',...
                                    int2str(obj.tracks(iT).FirstFrame),', ',...
                                    int2str(obj.tracks(iT).LastFrame)];
                            else
                                
                                rowStr = ' , , ';
                            end
                            
                            %Parse the data in each column
                            for iP = 1:numel(obj.metadata.propertyNames)
                                
                                currProp = obj.metadata.propertyNames{iP};
                                
                                if ~obj.pinfo.(currProp).isTracked
                                    if iData == 1
                                        if iscell(obj.tracks(iT).(currProp))
                                            rowStr = [rowStr, ', ', writeStr(obj.tracks(iT).(currProp){:})];
                                        else
                                            %Write the untracked data on
                                            %the first row only
                                            rowStr = [rowStr, ', ', writeStr(obj.tracks(iT).(currProp))];
                                        end
                                    else
                                        rowStr = [rowStr,', '];
                                    end
                                else
                                    if iscell(obj.tracks(iT).(currProp))
                                        rowStr = [rowStr,', ', writeStr(obj.tracks(iT).(currProp){iData})];
                                    else
                                        rowStr = [rowStr,', ', writeStr(obj.tracks(iT).(currProp)(iData,:))];
                                    end
                                end
                            end
                            
                            %Write the row to the file
                            fprintf(fid,'%s\n',rowStr);
                        end
                    end
                    
                    %Close the file
                    fclose(fid);
                    
                case '.mat'    %Save as a MAT file with structure
                    
                    data.track = obj.tracks;
                    data.metadata = obj.metadata;
                    data.genealogy = obj.genealogy;
                    
                    save(filename,'data');
                    
            end
            
            function strOut = writeStr(dataIn)
                
                if ischar(dataIn)
                    strOut = dataIn;
                else
                    strOut = '';
                    for ll = 1:numel(dataIn)
                        try
                            strOut = [strOut, ' ', num2str(dataIn(ll))];
                        catch
                            keyboard
                        end
                    end
                    
                end
                
            end
            
        end

    end
        
    methods (Access = private) %Data input validation functions
        
        function trackDataIn = validateInputTrack(obj,trackDataIn)
            %Validate input track data
            %  Checks:
            %    (1) Input track data is a structure
            %    (2) Input track fieldnames have already been declared
            %    (3) Finds missing fields and appends the default values to
            %    them
            
            %Validate the inputs
            if ~isstruct(trackDataIn)
                error('timeseriesdata:validateInputTrack:InputNotStruct',...
                    'Input data must be a structure');
            end
                        
            %Check that the input track property names exist
            inputPropList = fieldnames(trackDataIn);
            for ii = 1:numel(inputPropList)
                if ~obj.propertyExists(inputPropList{ii})
                    error('timeseriesdata:validateInputTrack:PropertyDoesNotExist',...
                        '%s is an unrecognized property',inputPropList{ii})
                end
                
                %Special handling for 'PixelIdxList' to maintain
                %compatibility with regionprops. Convert the value into a
                %cell.
                if strcmp(inputPropList{ii},'PixelIdxList')
                    for iT = 1:numel(trackDataIn)
                        if ~iscell(trackDataIn(iT).PixelIdxList)
                             trackDataIn(iT).PixelIdxList = {trackDataIn(iT).PixelIdxList};
                        end
                    end
                end
            end
            
            %Validate that the number of datapoints in each entry is the
            %same. For numeric (matrix/vectors) input, the number of
            %datapoints is the number of rows. For cells, it is just the
            %number of elements.
            for inputIdx = 1:numel(trackDataIn)
                numData = nan(numel(inputPropList),1);
                
                for iP = 1:numel(inputPropList)
                    if any(strcmp(inputPropList{iP},{'MotherIdx','DaughterIdx','StartFrame','LastFrame','TrackLen'}))
                    
                    else
                        if obj.pinfo.(inputPropList{iP}).isTracked
                            if iscell(trackDataIn(inputIdx).(inputPropList{iP}))
                                numData(iP) = numel(trackDataIn(inputIdx).(inputPropList{iP}));
                            elseif isnumeric(trackDataIn(inputIdx).(inputPropList{iP}))
                                numData(iP) = size(trackDataIn(inputIdx).(inputPropList{iP}),1);
                            elseif ischar(trackDataIn(inputIdx).(inputPropList{iP}))
                                numData(iP) = 1;
                            end
                        end
                    end
                end
                
                if ~(range(numData) == 0)
                    error('timeseriesdata:InvalidDataSize',...
                        'Number of input tracked data is not the same for all fields.')
                end
            end
            
        end
        
        function trackDataIn = addMissingProperties(obj,trackDataIn,varargin)
            
            %Get list of required properties
            reqPropNames = obj.metadata.propertyNames;
            
            %Check whether to include only tracked properties (default) or
            %all properties
            addAllMissingProps = false;
            if ~isempty(varargin)
                if strcmpi(varargin{1},'all')
                    addAllMissingProps = true;
                end
            end
            
            
            %Check for missing properties. If any missing, replace with
            %default values
            newTrackPropNames = fieldnames(trackDataIn);
            missingValues = ~(ismissing(reqPropNames,newTrackPropNames));
            
            if any(missingValues)
                idxMissingProps = (find(missingValues))';
                
                for ii = idxMissingProps
                    currMissingProperty = reqPropNames{ii};
                    
                    %If all properties are requested, then add them.
                    %Otherwise, add only tracked properties.
                    if addAllMissingProps || obj.pinfo.(currMissingProperty).isTracked
                        [trackDataIn(:).(currMissingProperty)] = deal(obj.pinfo.(currMissingProperty).defaultValue);
                    end
                end
            end
            
        end
                
        function propExists = propertyExists(obj,propertyIn)
            %Checks the supplied property (or list of properties) against
            %the allowed datafields to see if the property currently
            %exists.
            
            if ~ischar(propertyIn)
                error('timeseriesdata:propertyExists:PropertyNotChar',...
                'Property name must be a char')
            end
            
            if ~isempty(obj.pinfo)
                %Check if the property name already exists
                if any(strcmp(propertyIn,obj.metadata.propertyNames))
                    propExists = true;
                else
                    propExists = false;
                end
            else
                propExists = false;
            end
        end
        
    end
    
    methods (Access = private) %Additional functions for merging data etc
       
        function sMerged = mergeStruct(obj,s1, s2)
            %MERGESTRUCT  Merge two structures
            %
            % S = MERGESTRUCT(S1,S2) merges two structures S1 and S2 into a
            % single output S. If the same fields are present in S1 and S2,
            % the elements in the fields are merged together.
            %
            % NOTE: S1 takes precedance over S2.
            
            sMerged = s1;
            
            fd = fieldnames(s2);
            
            for iF = 1:numel(fd)
                currField = fd{iF};
                
                if isfield(sMerged,currField) && obj.pinfo.(currField).isTracked
                    if iscell(sMerged.(currField))
                        %If s1 is a cell, then just add to end
                        if ~iscell(s2.(currField))
                            s2.(currField) = mat2cell(s2.(currField),ones(size(s2.(currField),1)),size(s2.(currField),2));
                        end
                        
                        sMerged.(currField) = [sMerged.(currField); s2.(currField)];

                    elseif isnumeric(s2.(currField)) && size(s2.(currField),2) == size(sMerged.(currField),2)
                        %Just matrix appending
                        sMerged.(currField) = [sMerged.(currField);s2.(currField)];
                    else
                        %If s2 is a cell, but s1 is not, then convert s1 to cell
                        sMerged.(currField) = mat2cell(sMerged.(currField),ones(size(sMerged.(currField),1),1),size(sMerged.(currField),2));
                        sMerged.(currField){end + 1,:} = s2.(currField);
                    end
                else
                    %If the field property is untracked, then replace the
                    %property value
                    sMerged.(currField) = s2.(currField);
                end
            end
                
        end
        
        function defaultStruct = makeDefault(obj,nFramesToAdd)
            
            %Construct a prototype dataset containing just the
            %default values
            defaultStruct = struct();
            for iP = 1:numel(obj.metadata.propertyNames)
                defaultStruct.(obj.metadata.propertyNames{iP}) = ...
                    repmat(obj.pinfo.(obj.metadata.propertyNames{iP}).defaultValue,nFramesToAdd,1);
            end
            
            
        end
        
        function obj = updateTrackLength(obj,trackIdx)
           %updateTrackLength  Update the track length
           %
           %  Calculates track length by taking difference between last
           %  frame and first frame. Updates the corresponding track Length
           %  property.
           
           obj.tracks(trackIdx).TrackLen = obj.tracks(trackIdx).LastFrame - obj.tracks(trackIdx).FirstFrame + 1;  
            
        end
      
    end
    
end