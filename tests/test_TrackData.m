classdef test_TrackData < matlab.unittest.TestCase
   
    methods (TestClassSetup)
        
        function addTbx(obj)
            %ADDTBX  Add the 'tbx' folder and sub-folders to the path
            
            currPath = path;
            obj.addTeardown(@path,currPath);
            addpath(genpath('../tbx/'));
        end
        
    end
    
    methods (Test)
        
        function verifyErrors_addFrame(TestCase)
            %VERIFYERRORS_ADDFRAME  Tests for input validation for addFrame
            
            sampleData = struct('Area', 5);
            
            trackObj = TrackData(5, sampleData);
            
            TestCase.assertEqual(trackObj.StartFrame, 5);
            
            TestCase.verifyError(@() trackObj.addFrame('s', sampleData),...
                'TrackData:addFrame:frameIndexNotNumeric');
            
            TestCase.verifyError(@() trackObj.addFrame([6 7], sampleData),...
                'TrackData:addFrame:frameIndexNotScalar');
            
            TestCase.verifyError(@() trackObj.addFrame(5, sampleData),...
                'TrackData:addFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.addFrame(6, {'Area', 20}),...
                'TrackData:addFrame:dataNotStruct');
            
        end
        
        function verify_addFrame_addToEnd(TestCase)
            %VERIFY_ADDFRAME_ADDTOEND  Verify addFrame works correctly when
            %adding to the end
            
            %Insert 2 consecutive frames
            trackObj = TrackData(3, struct('Area',5'));
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,2);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[5, 10]);
                        
        end
        
        function verify_addFrame_addToEndWithSkip(TestCase)
            %VERIFY_ADDFRAME_ADDTOENDWITHSKIP Verify addFrame works
            %correctly when adding to the end with a skip
            
            %Insert 2 consecutive frames
            trackObj = TrackData(3, struct('Area',5'));
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            %Skip frame 5
            trackObj = trackObj.addFrame(6, struct('Area',30'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,4);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[5, 10, 30]);
            
        end
        
        function verify_addFrame_addToStart(TestCase)
            %VERIFY_ADDFRAME_ADDTOSTART  Verify addFrame works correctly
            %when adding to the start
            
            %Insert 3 consecutive frames
            trackObj = TrackData(5, struct('Area',5'));
            trackObj = trackObj.addFrame(6, struct('Area',30'));
            trackObj = trackObj.addFrame(7, struct('Area',40'));
            
            %Insert a frame at the start
            trackObj = trackObj.addFrame(4, struct('Area',10'));
            
            %Check that the number of frames is correct
            TestCase.verifyEqual(trackObj.NumFrames,4);
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 5, 30, 40]);
            
        end
        
        function verifyErrors_deleteFrame(TestCase)
            %VERIFYERRORS_ADDFRAME  Tests for input validation for addFrame
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
           
            TestCase.verifyError(@() trackObj.deleteFrame('s'),...
                'TrackData:deleteFrame:frameIndexNotNumeric');
            
            TestCase.verifyError(@() trackObj.deleteFrame([5, 8, 9]),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.deleteFrame(1),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
            TestCase.verifyError(@() trackObj.deleteFrame(9),...
                'TrackData:deleteFrame:frameIndexInvalid');
            
        end
                
        function verify_deleteFrame_singleFrames(TestCase)
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            
            TestCase.assertEqual(trackObj.StartFrame, 5);
            TestCase.assertEqual(trackObj.EndFrame, 8);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame(5);
            
            TestCase.verifyEqual(trackObj.NumFrames,3)
            TestCase.verifyEqual(trackObj.StartFrame,6)
            
            %Delete last frame and check that the end frame index is
            %reduced
            trackObj = trackObj.deleteFrame(8);
            
            TestCase.verifyEqual(trackObj.NumFrames,2)
            TestCase.verifyEqual(trackObj.EndFrame,7)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 20]);
        end
        
        function verify_deleteFrame_multiFrames(TestCase)
            
            trackObj = TrackData(5, struct('Area', 5));
            trackObj = trackObj.addFrame(6, struct('Area', 10));
            trackObj = trackObj.addFrame(7, struct('Area', 20));
            trackObj = trackObj.addFrame(8, struct('Area', 40));
            
            TestCase.assertEqual(trackObj.StartFrame, 5);
            TestCase.assertEqual(trackObj.EndFrame, 8);
            
            %Delete first frame and check that the start frame index is
            %reduced
            trackObj = trackObj.deleteFrame([5, 8]);
            
            TestCase.verifyEqual(trackObj.NumFrames,2)
            TestCase.verifyEqual(trackObj.StartFrame,6)
            TestCase.verifyEqual(trackObj.EndFrame,7)
            
            %Check that the data is correct
            TestCase.verifyEqual([trackObj.Data.Area],[10, 20]);
        end
        
    end
    
end