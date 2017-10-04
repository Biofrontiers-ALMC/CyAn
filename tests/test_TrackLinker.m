classdef test_TrackLinker < matlab.unittest.TestCase
    
    properties
        
        %Test file
        testFile = 'D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2';
        
        importList %List of imported functions
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
            testObj = tracking.TrackLinker;
            obj.assertClass(testObj,'tracking.TrackLinker');
        end
        
        function verify_computeScore_Euclidean(obj)
            %Check that the compute score is giving the right values
            
            testObj = tracking.TrackLinker;
            
            AA = [1 4 2 3 4];
            BB = [1 3 5 3 5];
            
            testScore = testObj.computeScore(AA,BB,'Euclidean');
            
            obj.verifyEqual(testScore, pdist2(AA,BB,'Euclidean'));
            
        end
                
        function verify_computeScore_PxIntersectUnique(obj)
            %Check that the compute score is giving the right values
            
            testObj = tracking.TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersectunique');
            
            obj.verifyEqual(testScore, 4/11);
            
        end
        
        function verify_computeScore_PxIntersect(obj)
            %Check that the compute score is giving the right values
            
            testObj = tracking.TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersect');
            
            obj.verifyEqual(testScore, 4);
            
        end
        

    end
    
end