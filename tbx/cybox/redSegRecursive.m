function LL = redSegRecursive(cellImage, opts)
%REDSEGRECURSIVE Use for segmenting cells in the brightfield (red) channel.
%   REDSEG(cellImage, opts) segments cells in cellImage with the options in
%   opts, carried over from the CyTracker function. Recommended
%   MaxCellMinDepth is 5. Recommended Threshold level is 10.

%Get a threshold
[nCnts, binEdges] = histcounts(cellImage(:),linspace(0, double(max(cellImage(:))), 150));
binCenters = diff(binEdges) + binEdges(1:end-1);

%Find the peak background
[bgPk, bgPkLoc] = max(nCnts);
%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * 1000, 1, 'first'); %Set thFactor
thLoc = thLoc + bgPkLoc-opts.thFactor; %Change this value to alter threshold
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
%Average area
medianArea = median([rpCells.Area]);
MAD = 1.4826 * median(abs([rpCells.Area] - medianArea));
outlierCells = find([rpCells.Area] > (medianArea + 3 * MAD));
outlierCells = [outlierCells, find([rpCells.Area] > max(opts.cellAreaLim))];
outlierCells = [outlierCells, find([rpCells.MinorAxisLength] > 45)];
outlierCells = [outlierCells, find([rpCells.MajorAxisLength]./[rpCells.MinorAxisLength] > 3.8)];
outlierCells = [outlierCells, find([rpCells.MajorAxisLength] > 115)];
outlierCells = unique(outlierCells);

prcTile = 50;

while ~isempty(outlierCells)

    for iCell = outlierCells
        
        currMask = false(size(mask));
        currMask(rpCells(iCell).PixelIdxList) = true;
        thLvl = prctile(cellImage(currMask), prcTile); %Increase to keep more white
        
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
    
    %Identify outlier cells and try to split them
    rpCells = regionprops(mask, {'Area','PixelIdxList','MajorAxisLength','MinorAxisLength'});
    %Average area
    medianArea = median([rpCells.Area]);
    MAD = 1.4826 * median(abs([rpCells.Area] - medianArea));
    outlierCells = find([rpCells.Area] > (medianArea + 3 * MAD));
    outlierCells = [outlierCells, find([rpCells.Area] > max(opts.cellAreaLim))];
    outlierCells = [outlierCells, find([rpCells.MinorAxisLength] > 45)];
    outlierCells = [outlierCells, find([rpCells.MajorAxisLength]./[rpCells.MinorAxisLength] > 3.8)];
    outlierCells = [outlierCells, find([rpCells.MajorAxisLength] > 115)];
    outlierCells = unique(outlierCells);

    prcTile = prcTile - 1;
    
end

%Draw as cylinders
rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
LL = CyTracker.drawCapsule(size(mask), rpCells);

end

