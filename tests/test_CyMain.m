classdef test_CyMain < matlab.unittest.TestCase
    
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
        
        function assert_class_CyMain(obj)
            %Make sure that the object is named correctly
            
            testObj = CyMain;
            
            obj.assertClass(testObj,'CyMain');
            
        end
        
        function test_process_file(obj)
            %Run a test on a single file
            
            testObj = CyMain;
            obj.verifyWarningFree(@() testObj.processFile(obj.testFile));
            
            
                        
            
        end
    end
    
end