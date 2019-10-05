%For post-processing manually corrected masks. Re-makes them all into
%cylinders to make manual correction easier and make the masks look nicer.

%First, load the file info
fileInfo = imfinfo(fullfile('/Users/nicholashill/Desktop/Matlab/Single Cell Analysis/ccmOp+V2+?ccmP Washout/20190930_N2P26_ccmOp+V2 + deltaccmP IPTG washout_seq0000_0004_crop_series1_masks.tif'));

%Then, load each page
for iFrame = 1:numel(fileInfo)
    currImg = imread(fileInfo(iFrame).Filename, iFrame);
    inputMask = currImg > 0;
    
    %Then, for each object, make it into a cylinder.
    rpCells = regionprops(inputMask,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation','Area'});
    outputMask = CyTracker.drawCapsule(size(inputMask), rpCells);
    outputMask = outputMask > 0;
    outputMask(boundarymask(newMask)) = 0;
    
    %Write to a new tiff stack
    imwrite(outputMask, 'testfile', 'TIFF')
end

