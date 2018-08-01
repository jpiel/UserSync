#!/bin/zsh
#
# Ce script permet l'installation et la preparation du systeme UserSync
# UserSync est une solution alternative ˆ mobileSync pour palier aux problemes de synchro des comptes mobiles
# 
# UserSync se compose de plusieurs elements :
# - rsync3
# - myUserSync.sh : script de synchronisation (logs dans fichier UserSync.log)
# - installUserSync.sh : ce script d'installation
# - UserSync.conf : fichier de configuration (contient aussi une liste des utilisateurs ˆ ne pas tester)
# - org.mosx.UserSyncConfig.plist : teste que les utilisateurs presents ont tous la configuration effectuee (launchd utilisateur)
#
# L'installation se decoupe en plusieurs etapes :
# 1) Copie des elements de UserSync dans /usr/local/ (bin et etc)
#    1.bis) Ajout d'un launchAgent systeme org.mosx.UserSyncConfig.plist
# 2) Creation de clefs de cryptage sans mot de passe si non presentes
# 3) Copie des clefs sur le serveur defini dans le fichier de conf
# 4) Ajout d'un launchAgent utilisateur pour lancer la syncro
#

CURRENT_DIR=$(dirname $0)
INSTALL_DIR="/usr/local"
WITH_INSTALL=1
INSTALL_ONLY=0

[ $# -gt 0 ] && [ $1 = "-activateUser" ] && {
  WITH_INSTALL=0
}

[ $# -gt 0 ] && [ $1 = "-installonly" ] && {
  INSTALL_ONLY=1
}

[ $# -gt 0 ] && {
  [ $1 != "-installonly" ] && [ $1 != "-activateUser" ] && echo "Mauvais parametres..." && exit 1
}

### PARTIE 1 ***
# Copie des elements de UserSync dans /usr/local/ (bin et etc)
# Si parametre -config utilise, cette partie est ignoree
[ $WITH_INSTALL -eq 1 ] && [ ${CURRENT_DIR} != ${INSTALL_DIR} ] && {
	# Creation des dossiers si non presents
  [ -d ${INSTALL_DIR}/bin ] || sudo mkdir -p ${INSTALL_DIR}/bin
  [ -d ${INSTALL_DIR}/etc ] || sudo mkdir -p ${INSTALL_DIR}/etc
	# Copie des scripts et de rsync3
  sudo cp ${CURRENT_DIR}/installUserSync.sh ${INSTALL_DIR}/bin/
  chmod 755 ${INSTALL_DIR}/bin/installUserSync.sh
  sudo cp ${CURRENT_DIR}/launchUserSync.sh ${INSTALL_DIR}/bin/
  chmod 755 ${INSTALL_DIR}/bin/launchUserSync.sh
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/UserSync.sh > ${INSTALL_DIR}/bin/UserSync.sh
  chmod 755 ${INSTALL_DIR}/bin/UserSync.sh
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/checkUserSync.sh > ${INSTALL_DIR}/bin/checkUserSync.sh
  chmod 755 ${INSTALL_DIR}/bin/checkUserSync.sh
  sudo cp ${CURRENT_DIR}/rsync3 ${INSTALL_DIR}/bin/
	# On installe les fichiers de config
  [ -f ${INSTALL_DIR}/etc/UserSync.conf ] && {
        diff /usr/local/etc/UserSync.conf.orig /usr/local/etc/UserSync.conf |grep -e "^> " |grep -v RSYNCRSH | cut -d\  -f2- >/usr/local/etc/UserSync.conf.local
  }
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/UserSync.conf >${INSTALL_DIR}/etc/UserSync.conf.default
  cp ${CURRENT_DIR}/etc/UserSync.conf.srv ${INSTALL_DIR}/etc/UserSync.conf.srv
  [ -f ${INSTALL_DIR}/etc/UserSync.conf.local ] || cp ${CURRENT_DIR}/etc/UserSync.conf.local ${INSTALL_DIR}/etc/UserSync.conf.local
    
	# On met en place le launchAgent systeme.
  [ -f /Library/LaunchAgents/org.mosx.UserSyncConfig.plist ] && sudo launchctl unload -w /Library/LaunchAgents/org.mosx.UserSyncConfig.plist
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/org.mosx.UserSyncConfig.plist >/Library/LaunchAgents/org.mosx.UserSyncConfig.plist
  sudo launchctl load -w /Library/LaunchAgents/org.mosx.UserSyncConfig.plist 
	# On met en place le launchDaemon.
  [ -f /Library/LaunchDaemons/org.mosx.UserSyncRootConfig.plist ] && sudo launchctl unload -w /Library/LaunchDaemons/org.mosx.UserSyncRootConfig.plist
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/org.mosx.UserSyncRootConfig.plist >/Library/LaunchDaemons/org.mosx.UserSyncRootConfig.plist
  sudo launchctl load -w /Library/LaunchDaemons/org.mosx.UserSyncRootConfig.plist 
	# On installe le patron du launchAgent utilisateur
  sudo sed "s&##INSTALL_DIR##&${INSTALL_DIR}&g" ${CURRENT_DIR}/org.mosx.UserSyncCron.plist >${INSTALL_DIR}/etc/org.mosx.UserSyncCron.plist
}

################
# Si parametre -installonly utilise, on arrete lˆ
[ $INSTALL_ONLY -eq 1 ] && exit 0
################

### PARTIE 2 ***
# Creation de clefs de cryptage sans mot de passe si non presentes

[ -d ~/.ssh ] || mkdir ~/.ssh
[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
grep -q "$(cat ~/.ssh/id_rsa.pub)" ~/.ssh/authorized_keys
[ $? -ne 0 ] && cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys

################

### PARTIE 3 ***
# Copie des clefs sur le serveur defini dans le fichier de conf

CONF_FILE="${INSTALL_DIR}/etc/UserSync.conf"
[ -f ${CONF_FILE} ] || {
  echo "Fichier de configuration non present, merci de reinstaller UserSync"
  exit 2
}
. ${INSTALL_DIR}/etc/UserSync.conf
${INSTALL_DIR}/bin/rsync3 --rsync-path=/usr/local/bin/rsync3 -avzE -e "ssh -o StrictHostKeyChecking=no" --stats --timeout=10 ~/.ssh ${SYNCSERVER}:./
################

### PARTIE 4 ***
# Ajout d'un launchd utilisateur pour lancer la synchro
[ -d ~/Library/LaunchAgents ] || mkdir ~/Library/LaunchAgents
[ -f ~/Library/LaunchAgents/org.mosx.UserSyncCron.plist ] && launchctl unload -w ~/Library/LaunchAgents/org.mosx.UserSyncCron.plist
cp ${INSTALL_DIR}/etc/org.mosx.UserSyncCron.plist  ~/Library/LaunchAgents/org.mosx.UserSyncCron.plist
launchctl load -w ~/Library/LaunchAgents/org.mosx.UserSyncCron.plist

################

