function LL = redSeg(cellImage, opts)
%REDSEG Use for segmenting cells in the brightfield (red) channel.
%   REDSEG(cellImage, opts) segments cells in cellImage with the options in
%   opts, carried over from the CyTracker function. Recommended
%   MaxCellMinDepth is 5. ThresholdLevel is currently not used in this
%   function.

%Get a threshold
[nCnts, binEdges] = histcounts(cellImage(:),linspace(0, double(max(cellImage(:))), 150));
binCenters = diff(binEdges) + binEdges(1:end-1);

%Find the peak background
[bgPk, bgPkLoc] = max(nCnts);
%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * 1000, 1, 'first'); %Set thFactor
thLoc = thLoc + bgPkLoc-10; %Change this value to alter threshold
thLvl = binCenters(thLoc);

%compute mask, take inverse, and fill holes
mask = cellImage > thLvl;
mask = imcomplement(mask);
mask = imfill(mask, 'holes');

%Separate the cell clumps using watershedding
dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, opts.maxCellminDepth);
LL = watershed(dd);
mask(LL == 0) = 0;

mask = bwareaopen(mask, 100);
mask = bwmorph(mask, 'thicken', 8);

%Identify outlier cells and try to split them
rpCells = regionprops(mask, {'Area','PixelIdxList','MajorAxisLength','MinorAxisLength'});
outlierCells = find([rpCells.Area] > max(opts.cellAreaLim));

for iCell = outlierCells
    
    currMask = false(size(mask));
    currMask(rpCells(iCell).PixelIdxList) = true;
    thLvl = prctile(cellImage(currMask), 50); %Increase to keep more white
    
    newMask = cellImage < thLvl;
    newMask(~currMask) = 0;
    
    newMask = imfill(newMask, 'holes');
    
    dd = -bwdist(~newMask);
    dd(~newMask) = -Inf;
    dd = imhmin(dd, opts.maxCellminDepth-2);
    LL = watershed(dd);
    newMask(LL == 0) = 0;
    
    newMask = bwareaopen(newMask, 100);
    newMask = bwmorph(newMask,'thicken', 8);
    
    %Replace the old masks
    mask(currMask) = 0;
    mask(currMask) = newMask(currMask);
end

%Draw as cylinders
rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
LL = CyTracker.drawCapsule(size(mask), rpCells);

end

