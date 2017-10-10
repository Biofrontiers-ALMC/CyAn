%TRACKSPECTRALIMAGES  Track cells in the spectral images

analyzerObj = CyMain;

%Track linking parameters
analyzerObj.LinkedBy = 'PixelIdxList';
analyzerObj.LinkCalculation = 'pxintersect';
analyzerObj.LinkingScoreRange = [1, 1/0.3];
analyzerObj.FrameRange = Inf;
analyzerObj.MaxTrackAge = 1;
analyzerObj.ChannelToSegment = '!CStack';

%Mitosis detection parameters
analyzerObj.MitosisScoreRange = [1, 1/0.3];
analyzerObj.MitosisLinkToFrame = -1;                    %What frame to link to/ This should be 0 for centroid/nearest neighbor or -1 for overlap (e.g. check with mother cell)

linker = analyzerObj.processFile('D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2');

