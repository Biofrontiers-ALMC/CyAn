function checkVersion
%CHECKVERSION  Checks that the version number in the toolbox has been
%updated

%Get tbx folder name
ls = dir('tbx');

for ii = 1:numel(ls)
    if ~ismember(ls(ii).name, {'.', '..'}) && ls(ii).isdir
        cPath = fullfile(ls(ii).folder, ls(ii).name, 'Contents.m');
        break;
    end
end

%Read the file into a variable
fid = fopen(cPath,'r');

if fid == -1
    error('Error opening file %s', cPath);
    return    
end

contents = textscan(fid, '%s', 'delimiter', '\n');
fclose(fid);

%--- Check for version number ---%

%If the line is NOT a version number, add it in
hasVersion = contains(lower(contents{1}{2}),'version');

if hasVersion
    
    %Check version number was incremented by comparing the date
    
        
      %If not, offer to increment build number
    
    %Check version number matches with PRJ version number
    
else
    
    %Ask user to add version
    error('The second line of Contents.m should be the version number.');
    
end

%--- Check for githash ---%

% %Check that there are no uncommitted changes
% [~, cmdOut] = system('git status -s');
% 
% if ~isempty(cmdOut)
%     error('There are uncommitted changes.');
% end

%Get the latest git hash
[~, lastHash] = system('git log --pretty=format:''%H'' -n 1');
lastHash = regexprep(lastHash, '[^a-z0-9]*',''); %Strip apostrophes

%Check that there are no unpushed data to the remotes
system('git fetch');
[~, cmdOut] = system(['git branch -r --contains ' lastHash]);

if ~contains(cmdOut,'master')
    error('The changes have not been pushed to the master branch');
end

%Look for git hash in code
hasGithash = contains(lower(contents{1}{3}),'git hash');

if hasGithash
        
    %Check that the value matches the latest git hash
    if ~contains(currLine, lastHash)
        
    end
    
    %If not, offer to increment build number
    
    %Check version number matches with PRJ version number
    
else
    
    gitHashLine = ['% Git hash ', lastHash];
    
    %Write the line in
    contents{1} = [contents{1}(1:2); {gitHashLine}; contents{1}(3:end)];
        
end

%Write the output
fid = fopen(cPath,'w');

if fid == -1
    error('Error opening file %s', cPath);
    return    
end

for ii = 1:numel(contents{1})
    fprintf(fid, '%s\n', contents{1}{ii});
end

fclose(fid);

end