classdef TrackData
    %TRACKDATA  Data class to hold data for a single track
    
    properties (Hidden)
        
        Data
       
        StartFrame = Inf;
        EndFrame = -Inf;
        MotherTrackIdx = NaN;
        DaughterTrackIdxs = NaN;
        
    end
    
    properties (Dependent)
        
        TrackDataProps      %Properties to check for
        NumFrames
       
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
           
            %Add the frame to the track
            if frameIndex > obj.EndFrame

                %Add frame to the end of the track
                if isinf(obj.StartFrame) && isinf(obj.EndFrame)
                    %If both start and end frames are infinite, then this
                    %is the first frame to be added
                    obj.Data = data;
                    
                    %If this is the first frame, also update the start and
                    %end frames
                    obj.StartFrame = frameIndex; 
                    obj.EndFrame = frameIndex;
                else
                    %Calculate the index of the data struct relative to the
                    %start frame
                    dataInd = frameIndex - obj.StartFrame + 1;
                    
                    %Add the data
                    obj.Data(dataInd) = data;
                end
                 
                %Update the frame numbers
                obj.EndFrame = frameIndex;
                               
            elseif frameIndex < obj.StartFrame
                %Add frame to the start of the track
                
                %Calculate the number of spaces to move the data
                dataInd = obj.StartFrame - frameIndex + 1;
                
                %Move the data
                oldData = obj.Data;
                
                obj.Data = data;
                obj.Data(dataInd:dataInd+numel(oldData) - 1) = oldData;
                
                obj.StartFrame = frameIndex;
                
            end
            
            
        end
        
        function obj = deleteFrame(obj, frameIndex)
            %DELETEFRAME  Deletes the specified frame
            %
            %  T = T.DELETEFRAME(f, frameIndex) deletes the specified frame
            %  from the track.
            %  
            %  See also: TrackData.updateTrack
            
            %Validate the frame number
            if ~isnumeric(frameIndex)
                error('TrackData:deleteFrame:frameIndexNotNumeric',...
                    'Expected the frame index to be a number.');
            else
                if ~(all(frameIndex >= obj.StartFrame & frameIndex <= obj.EndFrame))
                    error('TrackData:deleteFrame:frameIndexInvalid',...
                        'The frame index should be between %d and %d.',...
                        obj.StartFrame, obj.EndFrame);
                end
            end
                       
            %Convert the frame index into the index for the data array
            dataInd = frameIndex - obj.StartFrame + 1;
            
            %Remove the frame
            obj.Data(dataInd) = [];
            
            %Update the start and end frames if the deleted frame was at
            %the start/end
            if any(frameIndex == obj.StartFrame)
                
                obj.StartFrame = obj.StartFrame + 1;
            end
            
            if any(frameIndex == obj.EndFrame)
                
                obj.EndFrame = obj.EndFrame - 1;
                
            end
                        
        end
        
    end
end








