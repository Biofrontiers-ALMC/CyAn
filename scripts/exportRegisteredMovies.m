bfr = BioformatsImage('D:\Jian\Documents\Projects\CameronLab\cy-growth-characterization\data\20181230 50pc Red Exponential\seq0000_xy01.nd2');
bfr.swapZandT = true;

ROI = [899 1177 800 800];


channel = 'Cy5';
channelExport = 'Cy5';

% vid = VideoWriter('D:\Jian\Documents\Projects\CameronLab\Datasets\Kristin\seq0000.avi');
% vid.FrameRate = 10;
% open(vid);
outputDir = 'C:\Users\Jian Tay\Desktop\cropped';

for iT = 1:bfr.sizeT
    
    currFrame = getPlane(bfr, 1, channel, iT, 'ROI', ROI);
    
    if iT == 1
        pxShift = [0, 0];
%         maxInt = 10 * max(currFrame(:));
    else
        pxShift = xcorrreg(lastFrame, currFrame);
    end
    
    corrImg = shiftimg(currFrame, pxShift);
%     corrImg = corrImg ./ max(corrImg(:));
    
%     writeVideo(vid, corrImg);

    lastFrame = corrImg;
    
    %Actual frame
    exportImg = getPlane(bfr, 1, channelExport, iT, 'ROI', ROI);
    exportImg = shiftimg(exportImg, pxShift);
    
    if iT == 1
        imwrite(exportImg, fullfile(outputDir, 'seq000_cy5.tiff'), ...
            'Compression', 'None');
    else
        imwrite(exportImg, fullfile(outputDir, 'seq000_cy5.tiff'), ...
            'Compression', 'None', 'writeMode', 'append');
    end
end
% close(vid);


function pxShift = xcorrreg(refImg, movedImg)
%REGISTERIMG  Register two images using cross-correlation
%
%  I = xcorrreg(R, M) registers two images by calculating the
%  cross-correlation between them. R is the reference or stationary image,
%  and M is the moved image.
%
%  Note: This algorithm only works for translational shifts, and will not
%  work for rotational shifts or image resizing.

%Compute the cross-correlation of the two images
crossCorr = ifft2((fft2(refImg) .* conj(fft2(movedImg))));

%Find the location in pixels of the maximum correlation
[xMax, yMax] = find(crossCorr == max(crossCorr(:)));

%Compute the relative shift in pixels
Xoffset = fftshift(-size(refImg,1)/2:(size(refImg,1)/2 - 1));
Yoffset = fftshift(-size(refImg,2)/2:(size(refImg,2)/2 - 1));

pxShift = round([Xoffset(xMax), Yoffset(yMax)]);

end

function corrImg = shiftimg(imgIn, pxShift)

%Translate the moved image to match
corrImg = circshift(imgIn, pxShift);

% shiftedVal = 0;
% 
% %Delete the shifted regions
% if pxShift(1) > 0
%     corrImg(1:pxShift(1),:) = shiftedVal;
% elseif pxShift(1) < 0
%     corrImg(end+pxShift(1):end,:) = shiftedVal;
% end
% 
% if pxShift(2) > 0
%     corrImg(:,1:pxShift(2)) = shiftedVal;
% elseif pxShift(2) < 0
%     corrImg(:,end+pxShift(2):end) = shiftedVal;
% end

end