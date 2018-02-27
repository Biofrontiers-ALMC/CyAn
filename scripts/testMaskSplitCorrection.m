%Script to test if a mask was correctly split apart

maskFile = 'testOut.tif';

numMasks = numel(imfinfo(maskFile));

for iT = 1:numMasks
    maskImg = imread(maskFile, iT);
    
    rp = regionprops(maskImg, 

end