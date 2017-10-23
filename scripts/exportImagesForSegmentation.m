bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2');

blankImage = zeros(bfr.height, bfr.width, 'uint16');

for iT = 1:bfr.sizeT
        
    clear currImage
    
    %Get the CStack
    for iC = 1:bfr.sizeC
        if ~exist('currImage','var')
            currImage = double(bfr.getPlane(1, iC, iT))/bfr.sizeC;
        else
            currImage = currImage + double(bfr.getPlane(1, iC, iT))/bfr.sizeC;
        end
    end
    
    currImage = normalizeimg(currImage);

    [~,fn] = fileparts(bfr.filename);
    
    if iT == 1
        imwrite(currImage,sprintf('%s.tif', fn))
        imwrite(blankImage,sprintf('%s.tif', fn),'writemode','append')
    else
        imwrite(currImage,sprintf('%s.tif', fn),'writemode','append')
        imwrite(blankImage,sprintf('%s.tif', fn),'writemode','append')
    end

    
end