classdef test_TrackLinker < matlab.unittest.TestCase
    
    properties
        
        %Test file
        testFile = 'D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2';
        
    end
    
    methods (TestClassSetup)
        
        function addTbx(obj)
            %ADDTBX  Add the 'tbx' folder and sub-folders to the path
            
            currPath = path;
            obj.addTeardown(@path,currPath);
            addpath(genpath('../tbx/'));
        end
        
    end
    
    methods (Test)
        
        function assert_class_TrackLinker(obj)
            %Make sure that the object is named correctly
            testObj = TrackLinker;
            obj.assertClass(testObj,'TrackLinker');
        end
        
        function verify_computeScore_Euclidean_rowvectors(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 4 2 3 4];
            BB = [1 3 5 3 5];
            
            testScore = testObj.computeScore(AA,BB,'Euclidean');
            
            expectedResults = zeros(1, size(AA,2));
            for ii = 1:size(AA,2)
                expectedResults(ii) = sqrt((AA(ii) - BB(ii)).^2);
            end
            
            obj.verifyEqual(testScore, expectedResults);
        end
        
        function verify_computeScore_Euclidean_vectors(obj)
            %Check that the euclidean score is correct when given a list of
            %vectors representing xy locations.
            
            testObj = TrackLinker;
            
            %Make sample data representing XY coordinates
            XY1 = rand(10,2);
            XY2 = [5, 2];
            
            expectedScore = zeros(1, size(XY1,1));
            for ii = 1:size(XY1,1)
                expectedScore(ii) = sqrt((XY1(ii,1) - XY2(1)).^2 + (XY1(ii,2) - XY2(2)).^2);
            end
            
            testScore = testObj.computeScore(XY1,XY2,'Euclidean');
            
            obj.verifyEqual(testScore, expectedScore);
            
            
        end
                
        function verify_computeScore_Euclidean_oneCell(obj)
            %Check that the euclidean score is correct when given a list of
            %vectors representing xy locations.
            
            testObj = TrackLinker;
            
            %Make sample data representing XY coordinates
            XY1 = cell(10,1);
            for ii = 1:10
                XY1{ii} = rand(1,2);
            end
            XY2 = [5, 2];
            
            expectedScore = zeros(1, size(XY1,1));
            for ii = 1:size(XY1,1)
                expectedScore(ii) = sqrt((XY1{ii}(1) - XY2(1)).^2 + (XY1{ii}(2) - XY2(2)).^2);
            end
            
            testScore = testObj.computeScore(XY1,XY2,'Euclidean');
            
            obj.verifyEqual(testScore, expectedScore);
            
        end
        
        function verify_computeScore_PxIntersectUnique(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersectunique');
            
            obj.verifyEqual(testScore, 4/11);
            
        end
        
        function verify_computeScore_PxIntersect(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersect');
            
            obj.verifyEqual(testScore, 4);
            
        end
        
        function verify_initializeLinkerWithTracks(obj)
            %Try initializing the linker with new tracks
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            
            obj.verifyEqual(numel(linkerObj.TrackArray), 5);
            
        end

        function verify_stopTrack(obj)
            %Verify that the StopTrack() method works
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            
            obj.assertEqual(numel(linkerObj.TrackArray), 5);
            obj.assertEqual([linkerObj.activeTracks.trackIdx], 1:5);
            
            %Stop tracking track 3
            linkerObj = linkerObj.StopTrack(3);
            
            obj.verifyEqual([linkerObj.activeTracks.trackIdx], [1, 2, 4, 5]);
            
        end
        
        function verify_assignToTrack(obj)
            %Verify that the assignToTrack() method works
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            obj.assertEqual(numel(linkerObj.TrackArray), 5);
            obj.assertEqual([linkerObj.activeTracks.trackIdx], 1:5);
            
            %Make move the tracks slightly.
            for ii = 1:5
                newTrackDataMoved(ii).Centroid = newTrackData(ii).Centroid + rand(1, 2);
            end
            
            %Assign the new detections to track
            linkerObj = linkerObj.assignToTrack(2, newTrackDataMoved);
            
            %Check that the tracks were assigned correctly
            for ii = 1:5
                currTrack = linkerObj.getTrack(ii);
                obj.verifyEqual(cat(1,currTrack.Data.Centroid), [newTrackData(ii).Centroid; newTrackDataMoved(ii).Centroid]);
            end
            
        end
        
    end
    
    methods (Test)
        
        function verifyError_MakeCostMatrix(obj)
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            linkerObj.LinkedBy = 'NotAProperty';
            
            obj.verifyError(@() linkerObj.assignToTrack(2, newTrackData),...
                'TrackLinker:MakeCostMatrix:NewDataMissingLinkField');
            
        end
        
    end
   
end