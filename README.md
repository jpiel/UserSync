# UserSync
A set of scripts to replace the sync of Mobile accounts in OS X

## Introduction
This scripts were developped first for my own purpose at my job. I was so annoyed about the way homeSync worked for Mobile Accounts on my different OS X computers. The most annoying things i noticed were :

- Sometimes old/deleted files came back to life, even if the MCX rules said the network should always win.
- Errors are displayed locally with a very annoying dialog that users complain about.
- Logs are cryptic.

So, the goal of this scripts is to replace the syncing via homeSync (except the first one, at account creation) with a silent process. I want to be sure the client always win, and that the server doesn't keep unwanted files. I want to be notified of errors by email, not by angry users. I want to have access to good logs and have control on their verbosity. 

## Prerequisites
You will need to have an rsync 3 binary. In my own installation, i did want to be sure to use the same version on all computers, so i installed it as rsync3 in `/usr/local/bin/` to not interact with possible local installations of rsync on this computers.

If you have rsync installed and want to use it, simply create `/usr/local/bin/rsync3` as a symbolic link to your rsync.

The same rsync3 binary is also needed on the server you'll sync to.

## Installation
The installation of UserScript is a 2-steps installation :

### 1) Installation of scripts
Before installing the scripts, you should prepare the UserSync.conf file to fit your configuration (server and emails).

Then you can simply install all the scripts by launching the following command :
`./installUserSync.sh -installonly`

### 2) Activation for one user
UserSync needs to be activated for each user on the computer you want to sync with the server. If you don't want to sync some local users, UserSync will warn you by email, and you have to put their name in the config file.

To activate UserSync for one user, login as this user, then launch the following command :
`/usr/local/bin/installUserSync.sh -activateUser`

This will ask for the user password to copy the ssh keys to the server.

### 3) That's all
Yes, that's all, if you have put the right information in the config file, it should just start syncing.

## Usage
UserSync is meant to works by itself and warn you when things are not going the way it should.

Some log files are created in the ~/.UserSync/ directory so you can check what is done.

If you want/need to change some options (rsync options for example), most of them are available in the config file `/usr/local/etc/UserSync.conf`. As a side note, this file is not overwritten by the -install option of the install script. The default config file is copied to `/usr/local/etc/UserSync.conf.orig`.

If you want to overwrite the config file, you will need to use one of this command :
`/usr/local/bin/installUserSync.sh -initconf` to replace the whole config file
`/usr/local/bin/installUserSync.sh -initconfWOusers` to replace the config file but keep the exluded users.

There is a per-user exclude file : `~/UserSync/exclude-list`. You will need to add an exclusion pattern per line.

## Improvments
Here are a few things that need to be improved :

- Check the rsync licence to see how i could include it with the set of the scripts.
- Create a package to distribute the script. See if a package with questions to fill the config file is an option, or if it is better to let people build the package with their own config file.
- When a lot of users are syncing at the same time, the delay may be very long, even with only a few files to transfer. Needs to check if that can be improved by changing some rsync options, or by using a rsync daemon, or both.
- Comments need to be translated in english.
- Needs to improve emails and the way they are generated.
- Needs to improve the way emails are sent to be able to use SMTP authentication.
- Think about a simple way to have centralized configuration on the server.
- Think about a way to update scripts automatically from the server.

## History

1.10 : Correction in the function calculeDelais() that indicate the number of minutes the script was blocked.
1.11 : Add the version of rsync to the email report.
1.12 : Optimisation with big files and nb max of rsync
1.13 : Bugs fixs
1.14 : Allow to not split for big files if needed
1.15 : Bugs fixs
1.16 : Changes in Sleep Time calculation
1.17 : Change in ssh compressions options. 
1.18 : Big changes in log files. Rewrite of config files management.
