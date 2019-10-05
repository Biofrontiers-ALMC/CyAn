function LL = nicksversion(cellImage, opts)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

%Pre-process the brightfield image: median filter and
%background subtraction
cellImage = double(cellImage);

bgImage = imopen(cellImage, strel('disk', 40));
cellImageTemp = cellImage - bgImage;
cellImageTemp = imgaussfilt(cellImageTemp, 2);

%Fit the background
[nCnts, xBins] = histcounts(cellImageTemp(:), 100);
nCnts = smooth(nCnts, 3);
xBins = diff(xBins) + xBins(1:end-1);

%                   %Find the peak background
[bgPk, bgPkLoc] = max(nCnts);

%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * 0.011, 1, 'first');
thLoc = thLoc + bgPkLoc;
thLvl = xBins(thLoc);

%Compute initial cell mask
mask = cellImageTemp > thLvl;
mask = imopen(mask, strel('disk', 3));
mask = imclose(mask, strel('disk', 3));
mask = imerode(mask, ones(1));

%Separate the cell clumps using watershedding
dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, opts.maxCellminDepth);
LL = watershed(dd);
mask(LL == 0) = 0;

%Tidy up
mask = imclearborder(mask);
mask = bwareaopen(mask, 100);
mask = bwmorph(mask,'thicken', 8);

%Filter out all objects with low StDev
mask = CyTracker.bgStDevFilter(cellImageTemp, mask, opts.thFactor);

%Identify outlier cells and try to split them
rpCells = regionprops(mask, {'Area','PixelIdxList','MajorAxisLength','MinorAxisLength'});

%Average area
medianArea = median([rpCells.Area]);
MAD = 1.4826 * median(abs([rpCells.Area] - medianArea));
outlierCells = find([rpCells.Area] > (medianArea + 3 * MAD));
outlierCells = [outlierCells, find([rpCells.Area] > max(opts.cellAreaLim))];
outlierCells = [outlierCells, find([rpCells.MinorAxisLength] > 40)]; %45 for WT, 40 for aging
outlierCells = [outlierCells, find([rpCells.MajorAxisLength]./[rpCells.MinorAxisLength] > 3.8)];
outlierCells = [outlierCells, find([rpCells.MajorAxisLength] > 105)]; %115 for WT, 105 for aging
outlierCells = unique(outlierCells);


%                     currPrcTile = 30;
%                     while ~isempty(outlierCells)
%
%                         currPrcTile = currPrcTile + 5;
for iCell = outlierCells
    
    currMask = false(size(mask));
    currMask(rpCells(iCell).PixelIdxList) = true;
    thLvl = prctile(cellImage(currMask), 40);
    
    newMask = cellImage > thLvl;
    newMask(~currMask) = 0;
    
%     newMask = imopen(newMask, strel('disk', 3));
%     newMask = imclose(newMask, strel('disk', 3));
%     newMask = imerode(newMask, ones(1));
    newMask = imfill(newMask, 'holes'); %Currently experimental
    
    dd = -bwdist(~newMask);
    dd(~newMask) = -Inf;
    dd = imhmin(dd, opts.maxCellminDepth);
    LL = watershed(dd);
    newMask(LL == 0) = 0;
    
    newMask = bwareaopen(newMask, 100);
    
    %Test for solidity once again
    %No more local thresholding, but perform intense watershedding
    innerRpCells = regionprops(newMask, {'Area','PixelIdxList','Solidity','MajorAxisLength','MinorAxisLength'});
    nonSolidCells = find([innerRpCells.Solidity] < 0.83 & [innerRpCells.Area] > 550);
    
    for iCell2 = nonSolidCells
        
        currMask2 = false(size(mask));
        currMask2(innerRpCells(iCell2).PixelIdxList) = true;
        newMask2 = currMask2;
        
        %Repeat the watershedding
        dd = -bwdist(~newMask2);
        dd(~newMask2) = -Inf;
        dd = imhmin(dd, opts.maxCellminDepth - 4);
        LL = watershed(dd);
        newMask2(LL == 0) = 0;
        newMask2 = bwareaopen(newMask2, 100);
        
        %Replace newMask
        newMask(currMask2) = 0;
        newMask(currMask2) = newMask2(currMask2);
    end
    
    newMask = bwmorph(newMask,'thicken', 8);
    
    %For all new cell objects, check stDev
    newMask = CyTracker.bgStDevFilter(cellImageTemp, newMask, opts.thFactor);
    
    %Replace the old masks
    mask(currMask) = 0;
    mask(currMask) = newMask(currMask);
    
end

%                         %Then, re-calculate outlier cells. If any exist,
%                         %repeat local thresholding, but slightly more
%                         %stringent each time
%                         outlierCells = [];
%
%                         %Identify outlier cells and try to split them
%                         rpCells = regionprops(mask, {'Area','PixelIdxList','MajorAxisLength','MinorAxisLength'});
%
%                         %Average area
%                         medianArea = median([rpCells.Area]);
%                         MAD = 1.4826 * median(abs([rpCells.Area] - medianArea));
%                         outlierCells = find([rpCells.Area] > (medianArea + 3 * MAD));
%                         outlierCells = [outlierCells, find([rpCells.Area] > max(cellAreaLim))];
%                         outlierCells = [outlierCells, find([rpCells.MinorAxisLength] > 45)];
%                         outlierCells = [outlierCells, find([rpCells.MajorAxisLength]./[rpCells.MinorAxisLength] > 3.8)];
%                         outlierCells = [outlierCells, find([rpCells.MajorAxisLength] > 115)];
%                         outlierCells = unique(outlierCells);
%
%                     end

%Do final check for escapee outliers
rpCells = regionprops(mask, {'Area','PixelIdxList','MajorAxisLength','MinorAxisLength'});

escapees = find([rpCells.Area] > max(opts.cellAreaLim));
escapees = [escapees, find([rpCells.MinorAxisLength] > 40)];
escapees = [escapees, find([rpCells.MajorAxisLength]./[rpCells.MinorAxisLength] > 3.8)];
escapees = [escapees, find([rpCells.MajorAxisLength] > 105)];
escapees = unique(escapees);


for iCell = escapees
    %Everything is same as above except
    %maxCellMinDepth changed to constant of 2
    %(lowered).
    currMask = false(size(mask));
    currMask(rpCells(iCell).PixelIdxList) = true;
    thLvl = prctile(cellImage(currMask), 40);
    
    newMask = cellImage > thLvl;
    newMask(~currMask) = 0;
    
    newMask = imopen(newMask, strel('disk', 3));
    newMask = imclose(newMask, strel('disk', 3));
    newMask = imerode(newMask, ones(1));
    newMask = imfill(newMask, 'holes'); %Currently experimental

    dd = -bwdist(~newMask);
    dd(~newMask) = -Inf;
    dd = imhmin(dd, opts.maxCellminDepth-3);
    LL = watershed(dd);
    newMask(LL == 0) = 0;
    
    newMask = bwareaopen(newMask, 100);
    newMask = bwmorph(newMask,'thicken', 8);
    
    %Replace the old masks
    mask(currMask) = 0;
    mask(currMask) = newMask(currMask);
    
end


LL = mask;
% %Redraw the masks using cylinders
% rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
% 
% LL = CyTracker.drawCapsule(size(mask), rpCells);
    
end




