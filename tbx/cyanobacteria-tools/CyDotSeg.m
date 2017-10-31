classdef CyDotSeg
    
    properties
        
        ChannelToSegment = 'GFP';
        FrameRange = 240;
    end
    
    methods
        
        function dataOut = analyzeFile(obj, filename)
            
            if ~exist('filename','var')
                [filename, filedir] = uigetfile({'*.nd2','ND2 file (*.nd2)'});
            end
            
            bfr = BioformatsImage(fullfile(filedir, filename));
            
            for iT = obj.FrameRange
                
                currImg = bfr.getPlane(1, obj.ChannelToSegment, iT);
                
                dotMask = obj.segmentDots(currImg);
                
                showoverlay(normalizeimg(currImg),dotMask,[0 1 0]);
                
            end
                        
        end
       
    end
    
    methods (Static)
        function dotMask = segmentDots(imageIn)
            %SEGMENTSPOTS  Finds spots            
           
            %Convert the carboxysome image to double
            imageIn = double(imageIn);
            
            %Apply a median filter to smooth the image
            imageIn = medfilt2(imageIn,[2 2]);
            
            %Find local maxima in the image using dilation
            dilCbxImage = imdilate(imageIn,strel('disk',2));
            dotMask = dilCbxImage == imageIn;
            
            
            
%             dotLabels = false(size(imageIn));
%             %Refine the dots by cell intensity
%             for iCell = 1:max(cellMask(:))
%                 
%                 currCellMask = cellMask == iCell;
%                 
%                 cellBgInt = mean(imageIn(currCellMask));
%                 
%                 currDotMask = dotMask & currCellMask;
%                 currDotMask(imageIn < 1.4 * cellBgInt) = 0;
%                 
%                 dotLabels = dotLabels | currDotMask;
%             end
%             
%             dotLabels = imdilate(dotLabels,[0 1 0; 1 1 1; 0 1 0]);
            
        end
        
        
    end
    
end