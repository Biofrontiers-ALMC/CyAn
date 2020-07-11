function LL = redSeg(cellImage, opts)
%REDSEG Use for segmenting cells in the brightfield (red) channel.
%
%   REDSEG(I, OPTS) segments cells in the image I. I should be a grayscale
%   image of the brightfield channel. OPTS is a struct containing the
%   following parameters for the segmentation:
%       * thFactor - Threshold factor (Recommended: 10)
%       * maxCellminDepth - Factor to avoid oversegmentation (Recommended: 5)
%       * cellAreaLim - [min, max] areas for cells
%
%   Example:
%   %Create the OPTS struct:
%   opts.maxCellminDepth = 5;
%   opts.thFactor = 10;
%   opts.cellAreaLim = [0 1000];
% 
%   %Run the segmentation on a grayscale image I
%   mask = redSeg(I, opts);

%Get a threshold
[nCnts, binEdges] = histcounts(cellImage(:),linspace(0, double(max(cellImage(:))), 150));
binCenters = diff(binEdges) + binEdges(1:end-1);

%Find the peak background
[~, bgPkLoc] = max(nCnts);

%Find point where counts drop to fraction of peak
thLoc = bgPkLoc - opts.thFactor; %Change this value to alter threshold
thLvl = binCenters(thLoc);

%Compute mask and fill holes
mask = cellImage < thLvl;
mask = imopen(mask, strel('disk', 3));
mask = imfill(mask, 'holes');

%Separate the cell clumps using watershedding
dd = -bwdist(~mask);
dd(~mask) = -Inf;
dd = imhmin(dd, opts.maxCellminDepth);
LL = watershed(dd);
mask(LL == 0) = 0;

mask = bwareaopen(mask, 100);
mask = bwmorph(mask, 'thicken', 5);

mask = imclearborder(mask);

%Identify outlier cells and try to split them
rpCells = regionprops(mask, {'Area','Image', 'BoundingBox'});
outlierCells = find([rpCells.Area] > max(opts.cellAreaLim));

for iCell = outlierCells
    
    bb = round(rpCells(iCell).BoundingBox);
    cropImage = cellImage(bb(2):(bb(2) + bb(4) - 1), ...
        bb(1):(bb(1)+bb(3) - 1));
    
    thLvl = prctile(cropImage(:), 50);
    
    newMask = cropImage < thLvl;
    newMask(~rpCells(iCell).Image) = false;
    newMask = imclose(newMask, strel('disk', 2));
    newMask = imfill(newMask, 'holes');
    
    dd = -bwdist(~newMask);
    dd(~newMask) = -Inf;
    dd = imhmin(dd, opts.maxCellminDepth);
    LL = watershed(dd);
    newMask(LL == 0) = 0;
    
    newMask = bwareaopen(newMask, 100);
    %newMask = bwmorph(newMask,'thicken', 5);
    
%     showoverlay(cropImage, bwperim(newMask));
%     keyboard

    %Replace the old masks
    replaceMask = mask(bb(2):(bb(2) + bb(4) - 1), ...
        bb(1):(bb(1)+bb(3) - 1));
    replaceMask(rpCells(iCell).Image) = false;
    replaceMask(newMask) = true;
    
    mask(bb(2):(bb(2) + bb(4) - 1), ...
        bb(1):(bb(1)+bb(3) - 1)) = replaceMask;
    
%     imshow(replaceMask);
%     keyboard
end

%Remove any cell that is too large anyway
largeCellMask = bwareaopen(mask, max(opts.cellAreaLim) * 2);
mask(largeCellMask) = false;

%Remove regions that are too small to be a cell
mask = bwareaopen(mask, min(opts.cellAreaLim));

% %Draw as cylinders
% rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
% LL = CyTracker.drawCapsule(size(mask), rpCells);
LL = mask;

end
