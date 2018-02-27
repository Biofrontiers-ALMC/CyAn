clearvars

bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\test for segmentation\Seq0000_crop.nd2');

vidObj = VideoWriter('test.avi');
vidObj.FrameRate = 10;
open(vidObj);

for iT = 1:bfr.sizeT
    
    originalImg = bfr.getPlane(1, 'BF offset', iT);
    cy5Img = bfr.getPlane(1, 'Cy5', iT);
    
    
    cellImage = medfilt2(originalImg,[3 3]);
    bgImage = imopen(cellImage, strel('disk', 20));
    
    cellImage = cellImage - bgImage;
        
    thFactor = 20;
    
    [nCnts, xBins] = histcounts(cellImage(:));
    xBins = diff(xBins) + xBins(1:end-1);
    
    gf = fit(xBins', nCnts', 'gauss1');
    
    %thFactor = 3;
    thLvl = gf.b1 + thFactor * gf.c1;
    
    mask = cellImage > thLvl;
    
    % showoverlay(cellImage, bwperim(mask));
    
    mask = imfill(mask, 'holes');
    mask = imopen(mask, strel('disk', 3));
    mask = imclose(mask, strel('disk', 3));
    
    mask = imerode(mask, ones(1));
    
    dd = -bwdist(~mask);
    dd(~mask) = -Inf;
    dd = imhmin(dd, 2);
    
    LL = watershed(dd);
    
    mask(LL == 0) = 0;
    
    mask = imclearborder(mask);
    
    cellLabels = bwmorph(mask,'thicken', 8);
    
    cellLabels = bwareaopen(cellLabels, 500);
    
    %Get the regionprops
    rpCells = regionprops(cellLabels,{'Centroid','MajorAxisLength','MinorAxisLength','Orientation'});
    %%
    refMask = drawCylinder(mask, rpCells);
    
    refRP = regionprops(refMask, 'Area');
    idxToDel = find([refRP.Area] < 500);
    
    for iD = idxToDel
        refMask(refMask == iD) = 0;
    end
    
    
%     figure(1)
%     showoverlay(originalImg, bwperim(cellLabels));
%     figure(2)
%     showoverlay(originalImg, label2rgb(refMask));

     imgOut = showoverlay(cy5Img, label2rgb(refMask));
     imgOut = double(imgOut);
     imgOut = imgOut ./ max(imgOut(:));
     vidObj.writeVideo(imgOut);
     
     
%      if iT == 1
%          imwrite(imgOut, 'testOut.tif');
%      else
%          imwrite(imgOut, 'testOut.tif','writemode','append');
%      end

end
close(vidObj);