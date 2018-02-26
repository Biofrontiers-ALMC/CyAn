function checkVersion

%Get tbx folder name
ls = dir('tbx');

for ii = 1:numel(ls)
    if ~ismember(ls(ii).name, {'.', '..'}) && ls(ii).isdir
        cPath = fullfile(ls(ii).folder, ls(ii).name, 'Contents.m');
        break;
    end
end

fid = fopen(cPath,'r');

if fid == -1
    error('Error opening file %s', cPath);
    return    
end

%Get the second line
currLine = fgetl(fid);
currLine = fgetl(fid);

%If the line is NOT a version number, add it in
isVersion = contains(lower(currLine),'version');

keyboard

if isVersion
    
    %Check version number was incremented by comparing the date
    
        
      %If not, offer to increment build number
    
    %Check version number matches with PRJ version number
    
else
    
    %Ask user to add version
    error('The second line of Contents.m should be the version number.');
    
end

%Check that the next line contains the git hash
currLine = fgetl(fid);

%If the line is NOT a version number, add it in
isGithash = contains(lower(currLine),'git hash');

if isGithash
    
    %Check that there are no uncommitted changes
    [~, cmdOut] = system('git status -s');
    
    if ~isempty(cmdOut)
        error('There are uncommitted changes.');
    end
    
    %Check that the value matches the latest git hash
    
    
    %If not, offer to increment build number
    
    %Check version number matches with PRJ version number
    
else
    
end


fclose(fid);



end