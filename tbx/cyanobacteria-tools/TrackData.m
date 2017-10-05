classdef TrackData
    %TRACKDATA  Data class to hold data for a single track
    
    properties (Hidden)
        
        Data
        FrameIndices

        MotherTrackIdx = NaN;
        DaughterTrackIdxs = NaN;
        
    end
    
    properties (Dependent)
        
        TrackDataProps      %Properties to check for
        NumFrames
        
        StartFrame = Inf;
        EndFrame = -Inf;
       
    end
    
    methods
        
        function obj = TrackData(varargin)
            %TRACKDATA  Constructor function for TrackData object
            
            if nargin > 0
                
                ip = inputParser;
                ip.addRequired('frameIndex', @(x) isnumeric(x) && isscalar(x));
                ip.addRequired('trackData', @(x) isstruct(x));
                ip.parse(varargin{:});

                obj = obj.addFrame(ip.Results.frameIndex, ip.Results.trackData);
                
            end
            
        end
        
        function numFrames = get.NumFrames(obj)
            %GET.NUMFRAMES  Get number of frames
            
            numFrames = (obj.EndFrame - obj.StartFrame) + 1;
            
        end        
        
        function dataProperties = get.TrackDataProps(obj)
            %GET.TRACKDATAPROPS  Get list of data properties
            %
            %  Data properties are quantities which are measured for each
            %  track.
            
            if isempty(obj.Data)
                dataProperties = '';
            else
                dataProperties = fieldnames(obj.Data);
            end
            
        end
        
        function startFrame = get.StartFrame(obj)
            
            if isempty(obj.Data)
                startFrame = -Inf;
            else
                startFrame = obj.Data(1).FrameIndex;
            end
            
        end        
        
        function endFrame = get.EndFrame(obj)
            
            if isempty(obj.Data)
                endFrame = -Inf;
            else
                endFrame = obj.Data(end).FrameIndex;
            end
            
        end
        
        function obj = addFrame(obj, frameIndex, data)
            %ADDFRAME  Add data for a frame
            %
            %  T = T.ADDFRAME(f, dataStruct) adds a new frame at index f to
            %  the start or the end of the track. The frame data should be
            %  in a structure, with the fieldnames of the structure
            %  corresponding to the measured data property name.
            %
            %  If the new frame data has a new property that was not
            %  present in the previous frames, the value for the missing
            %  data will be empty ([]).
            %
            %  Example:
            %
            %    T = TrackData(1, struct('Area', 5));
            %    
            %    %In frame 2, 'Area' is no longer measured, but 'Centroid'
            %    %is
            %    T = T.ADDFRAME(2, struct('Centroid', [10 20]));
            %
            %    %These are the expected outputs:
            %    T.Data(1).Area = 2
            %    T.Data(1).Centroid = []
            %
            %    T.Data(2).Area = []
            %    T.Data(2).Centroid = [10 20]
            %  
            %  See also: TrackData.updateTrack
            
            %Validate the frame number
            if ~isnumeric(frameIndex)
                error('TrackData:addFrame:frameIndexNotNumeric',...
                    'Expected the frame index to be a number.');
                
            elseif ~isscalar(frameIndex)
                error('TrackData:addFrame:frameIndexNotScalar',...
                    'Expected the frame index to be a scalar number.');
                
            else
                if ~(frameIndex < obj.StartFrame || frameIndex > obj.EndFrame)
                        
                    error('TrackData:addFrame:frameIndexInvalid',...
                        'The frame index should be < %d or > %d.',...
                        obj.StartFrame, obj.EndFrame);
                end
            end
            
            %Valide the input data
            if ~isstruct(data)
                error('TrackData:addFrame:dataNotStruct',...
                    'Expected data to be a struct.');                
            end
           
            %Add the frame index as a field to the data
            data.FrameIndex = frameIndex;
            
            %Add the frame to the track
            if frameIndex > obj.EndFrame

                if isinf(obj.StartFrame) && isinf(obj.EndFrame)
                    %If both start and end frames are infinite, then this
                    %is the first frame to be added
                    obj.Data = data;
                    obj.Data(1).FrameIndex = frameIndex;        
                    
                else
                    %Calculate the number of frames to add
                    numFramesToAdd = frameIndex - obj.EndFrame;
                    
                    %Add missing frames (if any). The missing frames only
                    %have the 'FrameIndex' property filled.
                    for iAdditional = 1:(numFramesToAdd - 1)
                        obj.Data(end + 1).FrameIndex = obj.EndFrame + 1;
                    end

                    %Add the frame to the end of the array
                    obj.Data(end + 1) = data;
                    
                end
                               
            elseif frameIndex < obj.StartFrame
                %Add the new frame to the start and move the old data to
                %the end.
                oldData = obj.Data;
                obj.Data = data;
                
                %Calculate the element to move the old data to
                dataInd = oldData(1).FrameIndex - obj.StartFrame + 1;
   
                obj.Data(dataInd:dataInd + numel(oldData) - 1) = oldData;
                
                %Update the frame indices
                for ii = 1:dataInd
                    obj.Data(ii).FrameIndex = frameIndex + (ii - 1);
                end
      
                
            end
            
            
        end
        
        function obj = deleteFrame(obj, frameIndex)
            %DELETEFRAME  Deletes the specified frame
            %
            %  T = T.DELETEFRAME(f, frameIndex) deletes the specified
            %  frame(s) from the track.
            %
            %  Examples:
            %
            %    %Create a track with four frames
            %    trackObj = TrackData;
            %    trackObj = trackObj.addFrame(1, struct('Area',5));
            %    trackObj = trackObj.addFrame(2, struct('Area',10));
            %    trackObj = trackObj.addFrame(3, struct('Area',20));
            %    trackObj = trackObj.addFrame(4, struct('Area',40));
            %
            %    %Delete frame 2
            %    trackObj = trackObj.deleteFrame(2);
            %
            %    %Delete frames 1 and 4
            %    trackOb = trackObj.deleteFrame([1, 4]);
            %  
            %  See also: TrackData.updateTrack
            
            %Validate the frame index input
            if isnumeric(frameIndex)
                if ~(all(frameIndex >= obj.StartFrame & frameIndex <= obj.EndFrame))
                    error('TrackData:deleteFrame:frameIndexInvalid',...
                        'The frame index should be between %d and %d.',...
                        obj.StartFrame, obj.EndFrame);
                end
                
                %Convert the frame index into the index for the data array
                dataInd = frameIndex - obj.StartFrame + 1;
                
            elseif islogical(frameIndex)
                if (numel(frameIndex) ~= obj.NumFrames) || (~isvector(frameIndex))
                    error('TrackData:deleteFrame:frameIndexInvalidSize',...
                        'If the frame index is a logical array, it must be a vector with the same number of elements as the number of frames.');
                end
                
                %If it is a logical array, the usual deletion syntax should
                %work
                dataInd = frameIndex;
                
            else
                error('TrackData:deleteFrame:frameIndexNotNumericOrLogical',...
                    'Expected the frame index to be a number or a logical array.');
            end
                       
            %Remove the frame(s)
            obj.Data(dataInd) = [];
            
            %Renumber the frames
            for ii = 2:numel(obj.Data)
                obj.Data(ii).FrameIndex = obj.StartFrame + ii - 1;
            end
                        
        end
        
    end
end








