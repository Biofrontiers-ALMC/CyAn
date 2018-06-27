%Example code to import the data into a binary tree for plotting

T = ds.BinTree;

%Pull out a cell lineage
currTrack = trackArray.getTrack(1);
isRoot = true;
queue = {currTrack};
while ~isempty(queue)
    
    currTrack = queue{1};

    %Build up the tree
    if ~isRoot
        T = addNode(T, int2str(currTrack.ID), 'Parent', int2str(currTrack.MotherIdx));
    else
        T = addNode(T, int2str(currTrack.ID));
        isRoot = false;
    end
    T = setNodeValue(T, int2str(currTrack.ID), currTrack.NumFrames);
    
    if ~isnan(currTrack.DaughterIdxs)
        queue{end + 1} = trackArray.getTrack(currTrack.DaughterIdxs(1));
        queue{end + 1} = trackArray.getTrack(currTrack.DaughterIdxs(2));
    end
   
    queue(1) = [];
end


