# Project Name

This project is a collection of code for segmenting and tracking cyanobacteria. It will include a number of different components including:
* Cell segmentation
* Cell tracking
* Dot counting
* Genealogy trees

List of people involved:
* Jian Wei Tay
* Jeffrey Cameron
* Kristin Moore

## Downloading and Installating the Toolbox

*Note: Full installation instructions can be found in the [Wiki](https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox/wikis/download).*

1. Download the latest version of the toolbox [here](https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox/wikis/download).
2. Open the downloaded file in MATLAB. Click on "install".

For a list of changes, consult the [changelog](CHANGELOG).

## Usage

Instructions on how to use the toolbox is on the [Wiki](https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox/wikis/home).

## Downloading the source code

The source code is available on the [biof-git repository](https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox). The ``master`` branch contains the latest stable code, while the ``development`` branch contains daily snapshots (these may not be working).

### Using the Gitlab interface

To download the source code:

1. Click on the **Repository** tab above.
2. Click on the **Download icon** and select the desired format. It is recommended that you download the "master" branch as it contains the latest stable code.

### Cloning using Git

*If this is your first time using Gitlab, you must [add an SSH key to your profile](#adding-an-ssh-key).*

To clone the repository using [Git](https://git-scm.com/):

1. Click on the **Project** tab above.
2. Look for the SSH box (you might need to maximize your browser window if the box is missing). Copy the SSH URL to the clipboard. The URL should look like: ``git@biof-git.colorado.edu:<groupname>/<projectname>.git``
3. **Windows:** Start the Git bash application and navigate to a folder of your choice.
   **Linux/Mac:** Start the Terminal application and navigate to a folder of your choice.
4. Enter the following command:

```
  git clone <SSH URL>
```

If you have any issues, please email the developer or bit-help@colorado.edu for help.

#### Adding an SSH key

If you are encountering authentication issues when trying to clone the repository, please make sure you have added an SSH key to your Gitlab account. You can check this by going to [your settings -> SSH Keys](https://biof-git.colorado.edu/profile/keys).

If you do not have an SSH key added, please generate a key ([instructions](https://biof-git.colorado.edu/help/ssh/README.md)). Add the public key to your profile before proceeding.

## Developer's Guide

### Directory structure

The directory of the Git repository is arranged according to the best practices described in [this MathWorks blog post](https://blogs.mathworks.com/developer/2017/01/13/matlab-toolbox-best-practices/).

The main toolbox code can be found under ``tbx\<project-name>``.

Full documentation of the code can be found on the [Wiki](https://biof-git.colorado.edu/cameron-lab/cyanobacteria-toolbox/wikis/code-reference/contents).

### Contributing to the code

#### Reporting bugs and issues

Please report bugs and issues using the [Image Analysis Redmine application](https://imagepm.colorado.edu/projects/cyanobacteria-toolbox/issues).

#### Merge/Pull requests

To contribute code directly, please submit a [Merge Request](https://docs.gitlab.com/ee/gitlab-basics/add-merge-request.html).

Note: In general, your code will have to pass the unit tests listed in the `tests` folder. You can check that they do by using the [`runtests` function in MATLAB](https://www.mathworks.com/help/matlab/ref/runtests.html).

## Licence

Unless otherwise noted, all code is copyright (c) Unversity of Colorado Boulder. All rights reserved.
