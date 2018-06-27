tic;
CT = CyTracker;

%TODO: Set up the other parameters as necessary
CT.ChannelToSegment = 'BF offset';
CT.LinkingScoreRange = [1 10];
CT.OutputMovie = false;

%Change parameters
mainOutputDir = 'D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\test\';
fileToProcess = 'D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\Segmentation\seq0000_xy2.nd2';

thresholdLevelRange = 3:0.5:6;
maxCellMinDepthRange = 1.5:0.5:3.5;
minCellArea = 500:100:1000;

ctr = 0;

for iTh = 1:numel(thresholdLevelRange)
    
    for iMC = 1:numel(maxCellMinDepthRange)
        
        for iMA = 1:numel(minCellArea)
            ctr = ctr + 1;
            
            CT.ThresholdLevel = thresholdLevelRange(iTh);
            CT.MaxCellMinDepth = maxCellMinDepthRange(iMC);
            CT.CellAreaLim = [minCellArea(iMA) 15000];
            
            process(CT, fileToProcess, fullfile(mainOutputDir, int2str(ctr)));
        end
        
    end
    
end
toc;


%% Analysis
[~, fname] = fileparts(fileToProcess);

numParams = numel(thresholdLevelRange) * numel(maxCellMinDepthRange) * numel(minCellArea);

prcTracks5to12 = nan(1, numParams);
prcArea = nan(1, numParams);

ctr = 0;
for iTh = 1:numel(thresholdLevelRange)
    
    for iMC = 1:numel(maxCellMinDepthRange)
        
        for iMA = 1:numel(minCellArea)
            
            trackLen = nan(1,trackArray.NumTracks);
            areas = [];
            ctr = ctr + 1;
            load(fullfile(mainOutputDir,num2str(ctr), [fname, '_series1.mat']));
            
            %Get track length
            for iTrack = 1:trackArray.NumTracks
                
                ct = getTrack(trackArray, iTrack);
                
                areas = [areas; ct.getData('Area')];
                trackLen(iTrack) = ct.NumFrames;
                
            end
            
            %Compute number of tracks between 5 and 12 frames
            prcTracks5to12(ctr) = nnz(trackLen >= 5 & trackLen <= 12)/trackArray.NumTracks;
            prcArea(ctr) = nnz(areas >= 1000 & areas <= 3000)/numel(areas);            
            
        end
        
    end
    
end

figure;
plot(prcTracks5to12)
hold on;
plot(prcArea)