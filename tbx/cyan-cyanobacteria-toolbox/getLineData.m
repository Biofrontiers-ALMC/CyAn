function lineData = getLineData(coords)
%GETLINEDATA  Measures data of a line
%
%  S = GETLINEDATA(C) returns a struct S containing data about
%  the line specified by the coordinate vector C. C must be an
%  Nx2 list of coordinates where C(:, 1) is x and C(:, 2) is y.
%  It is expected that the points in C is connected by no more
%  than 1.4 pixels (i.e. the object mask is 8-connected).
%
%  S has the following fields:
%     Centroid = Center coordinate of the line
%     Length = Length of the line
%     SortedCoords = Sorted coordinates of the line
%     Excluded = Any coordinates that were excluded
%
%  The SortedCoords will be an Nx2 matrix specifying
%  coordinates going from one end of the line to the other.
%
%  Excluded contains a list of coordinates that were excluded
%  from the line. These are points that did not connect to the
%  traced line, e.g. if there was a branch.
%
%  The algorithm works by first tracing the points to find an
%  end point. The cumulative distance to the end point is then
%  computed and used to order the points as well as getting the
%  length of the line. The middle point is then the point that
%  is closest to the length/2.
%
%  Example:
%  %Assume after segmentation and skeletonization you have a
%  %mask. Note the use of 'PixelList' instead of
%  %'PixelIdxList'.
%  data = regionprops(mask, 'PixelList');
%
%  lineData = ActinTracker.findLineCenter(data.PixelList);


%Initialize variables
isSorted = [true; false(size(coords, 1) - 1, 1)];  %Flag if point has been sorted
sortIdx = [1; zeros(size(coords, 1) - 1, 1)];  %To store sorted indices
ptrLastIndex = 1;  %Position of sort index to add to

%Find an end point by travelling in one direction from the
%first pixel.
minInd = 1;  %Start at the first coordinate
while ~all(isSorted)
    
    %Find the next nearest pixel
    sqDistToPtr = sum((coords - coords(minInd, :)).^2, 2);
    sqDistToPtr(isSorted) = Inf;
    
    [minDist, minInd] = min(sqDistToPtr);
    
    if minDist <= 50000
        isSorted(minInd) = true;
        
        %Append to sorted indices
        ptrLastIndex = ptrLastIndex + 1;
        sortIdx(ptrLastIndex) = minInd;
        
    else
        break;
    end
end

%Shift the indices to the end of the array
sortIdx = circshift(sortIdx, nnz(~isSorted));

%Pointer will now count upwards so update the value
ptrLastIndex = nnz(~isSorted) + 1;

minInd = 1; %Reset the point back to the first coordinate
while ~all(isSorted)
    
    %Find the next nearest pixel
    sqDistToPtr = sum((coords - coords(minInd, :)).^2, 2);
    sqDistToPtr(isSorted) = Inf;
    
    [minDist, minInd] = min(sqDistToPtr);
    
    if minDist <= 50000
        isSorted(minInd) = true;
        
        %Add to sorted indices going upwards
        ptrLastIndex = ptrLastIndex - 1;
        sortIdx(ptrLastIndex) = minInd;
        
    else
        break;
    end
    
end

%Sort the array
lineData.SortedCoords = coords(sortIdx, :);

%Compute the line length
distFromEnd = [0; cumsum(sqrt(sum((diff(lineData.SortedCoords)).^2, 2)))];
lineData.Length = distFromEnd(end);

%Find the center coordinate of the line
[~, midPtLoc] = min(abs(distFromEnd - lineData.Length/2));
lineData.Centroid = lineData.SortedCoords(midPtLoc, :);

%Report any excluded data points
lineData.Excluded = coords(~isSorted, :);

end