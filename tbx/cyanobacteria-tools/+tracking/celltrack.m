classdef celltrack
    %CELLTRACK  Back-compatibility for version 0.9.0
    %
    %  **NOTE: This is not a working version of the celltrack object. The
    %  class definition only contains a single function: 'export' which is
    %  used to save the data as a structure for loading into the
    %  v1.0.0 code.**
    %
    %  **IF YOU ARE STILL USING THIS CODE, PLEASE EXPORT YOUR DATA AS THIS
    %  VERSION IS NO LONGER SUPPORTED**
    
    properties
        Data
        datafields = {};
        datafieldIsTracked
        
        version = 'v0.9.0';
    end
    
    methods
        
        function obj = celltrack(varargin)
            
            fprintf('**PLEASE EXPORT YOUR DATA AS THIS VERSION IS NO LONGER SUPPORTED**\n');
            
        end
        
        function export(obj,filename)
            %Exports the data as a structure for compatibility
            %
            % export(obj, filename)
            dataprop = fieldnames(obj.Data);
            
            for iT = 1:numel(obj.Data)
                for iD = 1:numel(dataprop)
                    
                    trackData(iT).(dataprop{iD}) = obj.Data(iT).(dataprop{iD});
                    
                end
            end
            
            trackData.version = 'v0.9.0';
            
            save(filename,'trackData')
            
        end        
        
    end
    
    
end