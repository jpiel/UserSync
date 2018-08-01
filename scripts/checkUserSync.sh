#!/bin/zsh 

# Ce script recupere la liste des utilisateurs locaux en regardant les dossiers presents dans /Users
# Pour tous les utilisateurs qui ne sont pas exclus dans le fichier de configuration (EXCLUDEDUSERS),
# on verifie si le launchAgent utilisateur a ete installe.
# Si il n'est pas installe, on envoie un email ˆ l'adresse EmailAdmin


INSTALL_DIR=/usr/local
. ${INSTALL_DIR}/etc/UserSync.conf.default
. ${INSTALL_DIR}/etc/UserSync.conf.srv
. ${INSTALL_DIR}/etc/UserSync.conf.local

emailAlert() {
  echo -ne "HELO ${MAILHOST}\r\n" > /tmp/sendMail.$$
  echo -ne "MAIL FROM: <${SENDER}>\r\n" >>  /tmp/sendMail.$$
  echo -ne "RCPT TO: ${EMAILADMIN}\r\n" >>  /tmp/sendMail.$$
  echo -ne "DATA\r\n" >>  /tmp/sendMail.$$
  echo -ne "From: ${SENDER}\r\n" >>  /tmp/sendMail.$$
  echo -ne "To: ${EMAILADMIN}\r\n" >>  /tmp/sendMail.$$
  echo -ne "Subject: Alerte UserSync sur $(hostname) : non active pour $1\r\n" >>  /tmp/sendMail.$$
  echo -ne "\r\n" >>  /tmp/sendMail.$$
  echo -ne "L'utilisateur $1 n'a pas UserSync de configure sur la machine $(hostname).\r\n" >>  /tmp/sendMail.$$
  echo -ne "Merci de le configurer ou de le rajouter a la liste des utilisateurs exclus.\r\n" >>  /tmp/sendMail.$$
  echo -ne ".\r\n" >>  /tmp/sendMail.$$
  echo -ne "QUIT\r\n" >>  /tmp/sendMail.$$

  /usr/bin/nc -v -i 1 ${MAILHOST} ${MAILPORT} < /tmp/sendMail.$$ >/dev/null 2>/dev/null
}

checkAll() {
  TMPUSERS=""
  ls -1 /Users |grep -v "Deleted Users" | grep -v ".DS_Store"| grep -v ".localized" |grep -v "Shared" | while read myuser
  do
    echo ,${EXCLUDEDUSERS}, |grep -q ,$myuser,
    [ $? -eq 1 ] && TMPUSERS=${TMPUSERS},$myuser
  done
  TMPUSERS=${TMPUSERS},
  
  TMPUSERS=${TMPUSERS#,*}
  while [ ! -z "$TMPUSERS" ]
  do
    checkUser ${TMPUSERS%%,*}
    TMPUSERS=${TMPUSERS#*,}
  done
}

checkUser() {
  if [ $# -eq 1 ]
  then
    USERTOTEST=$1
  else
    USERTOTEST=$(id -un)
    echo ,${EXCLUDEDUSERS}, |grep -q ,$USERTOTEST,
    [ $? -eq 0 ] && USERTOTEST=""
    [ "$USERTOTEST" = "root" ] && USERTOTEST=""
  fi
  [ -z "$USERTOTEST" ] || {
    [ -f /Users/${USERTOTEST}/Library/LaunchAgents/org.mosx.UserSyncCron.plist ] || emailAlert ${USERTOTEST}
  }
}

checkProcess() {
  ps -x |grep "/bin/UserSync.sh"|grep -v grep| while read procline
  do
    procid=$(echo $procline |cut -f1 -d' ')
    kill -9 $procid
#    echo killing $procline >>/usr/local/etc/UserCheck.log
#    echo $(date "+%Y-%m-%d--%H:%M:%S :") "Fin des process en cours au login." >>~/.UserSync/History.log
    [ -f ~/Library/LaunchAgents/org.mosx.UserSyncCron.plist ] && {
      sleep 30
      /bin/launchctl start org.mosx.UserSyncCron
    }
  done
}

[ "$1" = "-checkSys" ] && {
  checkAll
}

[ "$1" = "-checkUsers" ] && {
  checkProcess
  checkUser
}

#echo $(date "+%Y-%m-%d--%H:%M:%S :") "USER($1) : $USER ($(id -un))" >>/usr/local/etc/UserCheck.log
exit 0
