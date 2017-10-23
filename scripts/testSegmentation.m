%This is a development script to test the segmentation algorithm on the
%different images
bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2');

for iT = 100;%1:10:bfr.sizeT
        
    
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



    thLvl = 0.05;

    currImage = normalizeimg(currImage);    
    mask = currImage > thLvl;
    
    mask = imopen(mask, strel('disk',5));
    mask = bwareaopen(mask, 300);
    mask = imfill(mask,'holes');
    mask = imclearborder(mask);    
    
    dd = -bwdist(~mask);
    dd(~mask) = -Inf;
    
    imgToWatershed = imhmin(dd,1);
    cellLabels = watershed(imgToWatershed);
    
    cellLabels = activecontour(currImage,cellLabels > 0);
    
    cellLabels = imclearborder(cellLabels);
    
    showoverlay(normalizeimg(currImage), bwperim(cellLabels), [0 1 1])
%     pause
%     
%     clear currImage
    
end