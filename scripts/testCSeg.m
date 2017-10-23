%This is a development script to test the segmentation algorithm on the
%different images
bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2');

segger = CSeg;

for iT = 1:10:bfr.sizeT
    
    %Get the CStack
    for iC = 1:bfr.sizeC
        if ~exist('currImage','var')
            currImage = double(bfr.getPlane(1, iC, iT))/bfr.sizeC;
        else
            currImage = currImage + double(bfr.getPlane(1, iC, iT))/bfr.sizeC;
        end
    end
    
%     %Get the image histogram
%     [nCnts, xBins] = histcounts(currImage(:));
%     xCenters = diff(xBins) + xBins(1:end-1);
%     plot(xCenters, nCnts);

    segmentedImage = CSeg.segmentImage(currImage);
        
    showoverlay(normalizeimg(segmentedImage), bwperim(mask), [0 1 1])
    pause
    
end