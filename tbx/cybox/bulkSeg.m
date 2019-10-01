function LL = bulkSeg(cellImage, opts)
%BULKSEG is a simplified version of segmentation that should be used for
%single images of cells (from bulk experiments), and not for movies. Uses
%old threshold level (picks out ThLvl percentile of brightest pixels)


%Pre-process the brightfield image: median filter and
%background subtraction
cellImageTemp = double(medfilt2(cellImage,[3 3]));

bgImage = imopen(cellImageTemp, strel('disk', 40));
cellImageTemp = cellImageTemp - bgImage;

%Fit the background
[nCnts, xBins] = histcounts(cellImageTemp(:), 100);
nCnts = smooth(nCnts, 3);
xBins = diff(xBins) + xBins(1:end-1);

%Find the peak background
[bgPk, bgPkLoc] = max(nCnts);

%Find point where counts drop to fraction of peak
thLoc = find(nCnts(bgPkLoc:end) <= bgPk * opts.thFactor, 1, 'first');
thLoc = thLoc + bgPkLoc;

thLvl = xBins(thLoc);

%Compute initial cell mask
mask = cellImageTemp > thLvl;

mask = imfill(mask, 'holes');
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
mask = bwmorph(mask,'thicken', 8);

%Filter out all objects with low StDev
maskCC = bwconncomp(mask);

stdBG = std(cellImageTemp(~mask));


stdObjs = []; %For analysis - not segmentation
for iObj = 1:maskCC.NumObjects
    
    stdObj = std(cellImageTemp(maskCC.PixelIdxList{iObj}));
    
    stdObjs(end + 1) = stdObj; %For analysis - not segmentation
    
    if stdObj < 1500
        mask(maskCC.PixelIdxList{iObj}) = 0;
    end
end

% nhist(stdObjs) %For analysis - not segmentation


%Redraw the masks using cylinders
rpCells = regionprops(mask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});

%Remove cells which are too small or too large
rpCells(([rpCells.Area] < min(opts.cellAreaLim)) | ([rpCells.Area] > max(opts.cellAreaLim))) = [];

LL = CyTracker.drawCapsule(size(mask), rpCells);

end

