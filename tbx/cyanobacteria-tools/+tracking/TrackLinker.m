classdef TrackLinker
    % LAPTRACKER  Associates tracks using the linear assignment framework
    %     
    %
    %   See also: timeseriesdata
    
    properties  %List of tracking parameters
       
        %Track linking parameters
        LinkedBy = 'Centroid';
        LinkCalculation = 'euclidean';
        LinkingScoreRange = [-Inf, Inf];
        
        MaxTrackAge = 2;
        
        %Mitosis detection parameters
        TrackMitosis = true;
        MinAgeSinceMitosis = 2;
        MitosisParameter = 'PixelIdxList';          %What property is used for mitosis detection?
        MitosisCalculation = 'pxintersect';
        MitosisScoreRange = [-Inf, Inf];
        
        %LAP solver
        LAPSolver = 'lapjv';
       
    end
    
    properties (SetAccess = private) %Track data
        
        %Track data is stored with the following syntax:
        %  Tracks(cellID).(property)
        %  Tracks(cellID).(channel).(property)

        Tracks
        
    end
    
    properties (SetAccess = private, Hidden)  %Last updated tracks
        
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
    
    methods
        
        function obj = TrackLinker(varargin)
            %TRACKLINKER  Constructor function
            %
            %  LinkerObj = TRACKLINKER will create a TrackLinker object.
            %
            %  LinkerObj = TRACKLINKER(1, inputData) will initialize the
            %  new object with input data at frame 1.
            
            if nargin > 0
                
                
                
            end
            
        end
        
        
    end
    
    methods (Hidden)
        
        function addTrack
            
            
            
        end
        
    end
     
    methods (Static)
        
        function score = computeScore(input1, input2, type)
            %COMPUTESCORE  Computes the score between two inputs
            %
            %  S = TrackLinker.COMPUTESCORE(A, B, type) will compute the
            %  score between A and B. The type of computation depends on
            %  the specified parameter.
            %
            %  'Type' can be {'Euclidean', 'PxIntersect'}
            
            switch lower(type)
                
                case 'euclidean'
                    %Check that the inputs are both vectors and have the
                    %same length
                    if ~(isvector(input1) && isvector(input2))
                       error('TrackLinker:ComputeScoreEuclidean:InputsNotVector',...
                           'Both inputs must be a vector for ''Euclidean''.');
                    elseif ~ (length(input1) == length(input2))
                        error('TrackLinker:ComputeScoreEuclidean:InputsNotSameLength',...
                           'Both inputs must be the same length for ''Euclidean''.');
                    end

                    %Calculate the euclidean distance
                    score = sqrt(sum((input1 - input2).^2));
                    
                case 'pxintersect'
                    %Check that the two inputs are both cell arrays of
                    %numbers
                    if ~(isvector(input1) && isvector(input2))
                        error('TrackLinker:ComputeScorePxIntersect:InputsNotVector',...
                            'Both inputs must be a vector for ''PxIntersect''.');
                    end
                    
                    %Calculate the number of intersecting pixels
                    score = sum(ismember(input1,input2));
                    
                case 'pxintersectunique'
                    %Check that the two inputs are both cell arrays of
                    %numbers
                    if ~(isvector(input1) && isvector(input2))
                        error('TrackLinker:ComputeScorePxIntersect:InputsNotVector',...
                            'Both inputs must be a vector for ''PxIntersect''.');
                    end
                    
                    %Calculate the number of intersecting pixels
                    score = sum(ismember(input1,input2)) / numel(unique([input1,input2]));
                    
                otherwise 
                    error('TrackLinker:ComputeScore:UnknownType',...
                        '''%s'' is an unknown score type.',type)
            
            end
            
            
        end
        
    end
  
    

end