classdef CSeg
    %CSEG  Cyanobacteria Segmentation Tool
    %
    
    properties
        
    
        
    end
    
    methods
        
        function labelsOut = segmentImage(obj, imageIn)
            
            
            
            
            
        end
        
    end
    
    methods (Static)
        
        function cellLabels = watershedLabels(cellImage, varargin)
            %GETCELLLABELS  Segment and label individual cells
            %
            %  L = CyMain.GETCELLLABELS(I) will segment the cells in image
            %  I, returning a labelled image L. Each value in L should
            %  correspond to an individual cell.
            %
            %  L = CyMain.GETCELLLABELS(I, M) will use image M to mark
            %  cells. M should be a fluroescent image (e.g. YFP, GFP) that
            %  fully fills the cells.
            
            if isempty(varargin)
                
                cellMarkerImg = [];
                
            else
                
                %TODO: Add the ability to have a cell marker image
                
            end
            
            
            %Normalize the cellImage
            cellImage = normalizeimg(cellImage);
            
            mask = cellImage > 0.05;
            
            mask = imopen(mask,strel('disk',2));
            mask = imclearborder(mask);
            
            %mask = activecontour(cellImage,mask);
            
            mask = bwareaopen(mask,100);
            mask = imopen(mask,strel('disk',2));
            
            mask = imfill(mask,'holes');
            
            %             CyMain.showoverlay(CyMain.normalizeimg(cellImage),bwperim(mask),[0 1 0]);
            %             keyboard
            
            
            if isempty(cellMarkerImg)
                
                dd = -bwdist(~mask);
                dd(~mask) = -Inf;
                
                imgToWatershed = imhmin(dd,1);
                
            else
                %TODO
                
                %%Find extended maxima in the cell marker channel
                %fgmarker = ColonyTracker.getCellMarker(cellMarkerImg);
                
                %%Invert the cell marker image so that the centers are dark
                %img = imcomplement(cellMarkerImg);
                
                %Mark the negative regions (e.g. regions that are not the cell
                %and each cell region)
                %markedImage = imimposemin(img, ~colonyMask | fgmarker);
                
            end
            
            cellLabels = watershed(imgToWatershed);
            cellLabels = imclearborder(cellLabels);
            
        end
        
        function thLvl = getThreshold(imageIn)
            %GETTHRESHOLD  Get a threshold level to binarize the image
            %
            %  T = CyMain.GETTHRESHOLD(I) will look for a suitable
            %  greyscale level T to binarize image I.
            %
            [nCnts, binEdges] = histcounts(imageIn(:),150);
            binCenters = diff(binEdges) + binEdges(1:end-1);
            
            %nCnts = smooth(nCnts,3);
            %            nCnts(1) = 0;
            %[~,locs] = findpeaks(nCnts,'Npeaks',2,'sortStr','descend','MinPeakDistance',5);
            
            %Determine the background intensity level
            [~,locs] = findpeaks(nCnts,'Npeaks',1,'sortStr','descend');
            
            thLvl = find(nCnts(locs:end) <= 0.2 * nCnts(locs));
            
            %             %Find valley
            %             [~,valleyLoc] = min(nCnts(locs(1):locs(2)));
            %
            %             thLvl = binCenters(valleyLoc + locs(1));
            
            if isempty(thLvl)
                warning('Threshold level not found')
                keyboard
            end
            
        end
        
        %Continuous Erosions to get cell markers
        
        
        
    end
    
    
end