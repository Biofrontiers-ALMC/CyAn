classdef TrackDataArray < handle
    %TRACKDATAARRAY  Data class to hold data for multiple tracks
    
    properties (SetAccess = private)
        
        Tracks  %TrackData objects
        
    end
    
    methods
        
        function addTrack(obj, frameIndex, trackData)
            %ADDTRACK  Add a track to the array
            %
            %  A.ADDTRACK(frameIndex, data) will add a new TrackData
            %  object, initializing it so it starts at the frame index
            %  and with the data specified. ''data'' should be a struct.
            
            if isempty(obj.Tracks)
                obj.Tracks = TrackData(frameIndex,trackData);
                
            else
                obj.Tracks(numel(obj) + 1) = TrackData(frameIndex,trackData);
            end
            
        end
        
        function deleteTrack(obj, trackIndex)
            %DELETETRACK  Remove a track
            %
            %  A.DELETETRACK(trackIndex) will remove the TrackData object
            %  at the index specified.
            
            if isempty(obj.Tracks)
                error('TrackDataArray:deleteTrack:ArrayIsEmpty',...
                    'The track data array is empty.');
            else
                obj.Tracks(trackIndex) = [];
            end
            
        end
        
        function numTracks = numel(obj)
            %NUMEL  Count number of TrackData objects in the array 
            
            numTracks = numel(obj.Tracks);
            
        end
                
    end
    
end