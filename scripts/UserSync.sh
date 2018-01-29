#!/bin/zsh
UserSyncVersion="1.17"

INSTALL_DIR=##INSTALL_DIR##

##############################################################################
## Chargement de la configuration.
##############################################################################
. ${INSTALL_DIR}/etc/UserSync.conf

#####################################
# Definition des valeurs par defaut :
 if [ -z "$NORSYNCZ" ] 
	then
	[ -z "RSYNCZ" ] && RSYNCZ="-z --skip-compress=gz/bz2/jpg/jpeg/ogg/mp3/mp4/mov/avi/vmdk/vmem"
else
	RSYNCZ=""
fi

[ -z "$RSYNCTIMEOUT" ] && RSYNCTIMEOUT="60"
RSYNCTIMEOUT="--timeout=$RSYNCTIMEOUT"
[ -z "$RSYNCBIGTIMEOUT" ] && RSYNCBIGTIMEOUT="300"
RSYNCBIGTIMEOUT="--timeout=$RSYNCBIGTIMEOUT"

[ -z "$RSYNCINPLACE" ] && RSYNCINPLACE="yes"
if [ "$RSYNCINPLACE" = "yes" ]
	then
	RSYNCINPLACE="--inplace --chmod=u+w"
else
	RSYNCINPLACE=""
fi

[ -z "$RSYNCEXCLUDES" ] && RSYNCEXCLUDES="--exclude=Caches --exclude=SyncService --exclude=.FileSync --exclude='IMAP*' --exclude='.Trash' --exclude='Saved Application State' --exclude='Autosave Information'"

[ -z "$RSYNCOPTS" ] && RSYNCOPTS="-aHXxvE --stats --numeric-ids --delete-excluded --delete-before --human-readable"

[ -z "$RSYNCRSH" ] && RSYNCRSH='--rsh="ssh -T -c aes128-ctr -o Compression=no -x"'

[ -z "$RSYNCSPLITSIZE" ] && RSYNCSPLITSIZE="500M"
if [ "$RSYNCSPLITSIZE" != "0" ]
	then
	RSYNCMAXSIZE="--max-size=${RSYNCSPLITSIZE}"
	RSYNCMINSIZE="--min-size=${RSYNCSPLITSIZE}-1"
else
	RSYNCMAXSIZE=""
	RSYNCMINSIZE=""
fi

[ -z "$NBMAXRSYNC" ] && NBMAXRSYNC=4
[ -z "$SRVSEMPATH" ] && SRVSEMPATH=/tmp/userSyncSem

RSYNCVER=$(${INSTALL_DIR}/bin/rsync3 --version |/usr/bin/head -1)

##############################################################################
##############################################################################

emailAlert() {
  echo -ne "HELO ${MAILHOST}\r\n" > /tmp/sendMail.$$
  echo -ne "MAIL FROM: <${SENDER}>\r\n" >>  /tmp/sendMail.$$
  echo -ne "RCPT TO: ${EMAILADMIN}\r\n" >>  /tmp/sendMail.$$
  echo -ne "DATA\r\n" >>  /tmp/sendMail.$$
  echo -ne "From: ${SENDER}\r\n" >>  /tmp/sendMail.$$
  echo -ne "To: ${EMAILADMIN}\r\n" >>  /tmp/sendMail.$$
  echo -ne "Subject: Alerte UserSync sur $(hostname) : ${1}\r\n" >>  /tmp/sendMail.$$
  echo -ne "\r\n" >>  /tmp/sendMail.$$
  echo -ne "UserSync : ${UserSyncVersion}\r\n" >>  /tmp/sendMail.$$
  echo -ne "${RSYNCVER}\r\n\r\n" >>  /tmp/sendMail.$$
  msgFile=""
  [ $# -ge 3 ] && [ "$3" = "-file" ] && msgFile=${2}
  if [ -z "$msgFile" ]
  then
	echo ${2} |while read line
	do
		echo -ne "$line\r\n"
	done >>  /tmp/sendMail.$$
  else
	cat ${2} |while read line
	do
		echo -ne "$line\r\n"
	done >> /tmp/sendMail.$$
  fi
  echo -ne ".\r\n" >>  /tmp/sendMail.$$
  echo -ne "QUIT\r\n" >>  /tmp/sendMail.$$

  /usr/bin/nc -v -i 1 ${MAILHOST} ${MAILPORT} < /tmp/sendMail.$$ >/dev/null 2>/dev/null
}

calculeDuree() {
	STARTH=${1%:*}
	STARTM=${1#*:}
	ENDH=${2%:*}
	ENDM=${2#*:}
	[ $ENDM -lt $STARTM ] && {
		let ENDM=ENDM+60
		let ENDH=ENDH-1
	}
	let 'RESULT=(ENDH-STARTH)*60+ENDM-STARTM'
	echo $RESULT
}


testNBRSync() {
	SEMFILE="${SRVSEMPATH}/$(hostname)--$(id -un)"
	
	NBRSYNC=$(ssh ${SYNCSERVER} "ps auxwww |grep 'rsync3 --server' |wc -l")
	let NBRSYNC=NBRSYNC/2

	ssh ${SYNCSERVER} "test -d ${SRVSEMPATH} || mkdir ${SRVSEMPATH}"
	ssh ${SYNCSERVER} "test -f ${SEMFILE} && rm -f ${SEMFILE}"
	NB_SEM=$(echo $(ssh ${SYNCSERVER} "ls -1 ${SRVSEMPATH}/* 2>/dev/null |wc -l"))
	
	[ $NBRSYNC -ge $NBMAXRSYNC ] || [ $NB_SEM -gt 0 ] && {
		let NB_SEM=NB_SEM+1
		ssh ${SYNCSERVER} "echo $NB_SEM >${SEMFILE}"
	}
	
	let SLEEPTIME=1+NB_SEM
	#let SLEEPTIME=SLEEPTIME\*60
	NB_WAIT=$(ssh ${SYNCSERVER} "find ${SRVSEMPATH} -type f -mtime -6h |wc -l")
	let SLEEPTIME=SLEEPTIME\*NB_WAIT
	
	while [ $NBRSYNC -ge $NBMAXRSYNC ]
	do
		echo "##### Trop de rsync sur le serveur, on patiente ${SLEEPTIME}s #####" >>~/.UserSync/UserSync.log
		sleep $SLEEPTIME
		NBRSYNC=$(ssh ${SYNCSERVER} "ps auxwww |grep 'rsync3 --server' |wc -l")
		let NBRSYNC=NBRSYNC/2
	done
	ssh ${SYNCSERVER} "test -f ${SEMFILE} && rm -f ${SEMFILE}"
}

SEMERRMSG="La synchronisation semble bloquee pour $(id -un),
le processus ne s'est pas lance pendant au moins ${NBTRYSEMAPHORE} fois
parceque le semaphore est toujours present.
Merci de verifier qu'il n'y a pas un probleme avec le script."

CONNERRMSG="Le serveur repond aux ping mais la connexion ne se fait pas.

Il faut verifier la liaison entre les machines et/ou la configuration de l'utilisateur."

RSYNCERRNUMBERS="EXIT VALUES 
__0..Success
__1..Syntax or usage error
__2..Protocol incompatibility
__3..Errors selecting input/output files, dirs
__4..Requested  action  not  supported: an attempt was made to manipulate 64-bit
.....files on a platform that cannot support them; or an option was specified that is
.....supported by the client and not by the server.
__5..Error starting client-server protocol
__6..Daemon unable to append to log-file
_10..Error in socket I/O
_11..Error in file I/O
_12..Error in rsync protocol data stream
_13..Errors with program diagnostics
_14..Error in IPC code
_20..Received SIGUSR1 or SIGINT
_21..Some error returned by waitpid()
_22..Error allocating core memory buffers
_23..Partial transfer due to error
_24..Partial transfer due to vanished source files (IGNORED)
_25..The --max-delete limit stopped deletions
_30..Timeout in data send/receive
_35..Timeout waiting for daemon connection
"

[ -d ~/.UserSync ] || mkdir ~/.UserSync 

## Teste de la config et de la presence du serveur :
/usr/bin/ssh ${SYNCSERVER} -o NumberOfPasswordPrompts=0 -q echo >/dev/null
[ $? -eq 0 ] || {
  ## On ping le serveur pour verifier si il est bien present. Si present, on a un probleme d'acces
  ping -c 1 -t 2 ${SYNCSERVER} >/dev/null 2>&1
  [ $? -eq 0 ] && {
	emailAlert "Probleme de connexion au serveur" "${CONNERRMSG}"
  }

  ## Le serveur n'est pas dispo, donc si un semaphore existe, il faut le supprimer car il ne peut y avoir de synchro en cours.
  [ -f ~/.UserSync/Semaphore ] && rm -f ~/.UserSync/Semaphore
  [ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S : ")Serveur Injoignable >>~/.UserSync/History.log
  exit 1
}

## On place/verifie un semaphore.
[ -f ~/.UserSync/Semaphore ] && {
  ## On verifie que le processus est en cours et que le semaphore n'est pas present par erreur...
  ps -x |grep UserSync.sh |grep -v grep | grep -v "$(echo $$)" | grep -q "${INSTALL_DIR}/bin/UserSync.sh"
  #ps -x |grep UserSync.sh |grep -v grep

  if [ $? -eq 0 ]
  then
    ## Le semaphore est present, on ne lance pas la synchro.
    ## Mais on incremente le compteur du semaphore pour savoir combien de synchro on a loupe.
    mysemnb=$(cat ~/.UserSync/Semaphore)
    let mysemnb=mysemnb+1
    echo $mysemnb >~/.UserSync/Semaphore
    [ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S : ")Semaphore present >>~/.UserSync/History.log
  
    ## Si $mysemnb est superieur ˆ NBTRYSEMAPHORE on envoie un mail d'alerte
    [ $mysemnb -ge ${NBTRYSEMAPHORE} ] && {
	  CURTIME=$(date "+%H:%M")
	  SEMTIME=$(stat -f "%SB" -t "%H:%M" ~/.UserSync/Semaphore)
	  DUREE=$(calculeDuree $SEMTIME $CURTIME)
      emailAlert "Synchro Bloquee (Demarrage: ${SEMTIME}  -- Duree : ${DUREE}mn)" "${SEMERRMSG}"
    }
    exit 1
  else
	[ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S : ")"Effacement du Semaphore inapproprie" >>~/.UserSync/History.log
    rm -f ~/.UserSync/Semaphore
  fi
}
echo 1 >~/.UserSync/Semaphore

[ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S : ")OK Debut >>~/.UserSync/History.log

testNBRSync

# Verification que le fichier d'exclusion existe :
EXCLFILE=$(echo ~/.UserSync/exclude-list)
[ -f ${EXCLFILE} ] || touch ${EXCLFILE}

## Lancement de la synchro
# tester option --skip-compress=gz/bz2/jpg/jpeg/ogg/mp3/mp4/mov/avi/vmdk/vmem pour amŽliorer traitement des compressŽs
if [ "$RSYNCSPLITSIZE" = "0" ]
	then
	echo "##### Syncro $(date) #####" >~/.UserSync/UserSync.log
else
	echo "##### Syncro ${RSYNCMINSIZE} $(date) #####" >~/.UserSync/UserSync.log
fi
RSYNCCMD="${INSTALL_DIR}/bin/rsync3 --rsync-path=/usr/local/bin/rsync3 ${RSYNCOPTS} ${RSYNCRSH} ${RSYNCINPLACE} ${RSYNCBIGTIMEOUT} ${RSYNCEXCLUDES} --exclude-from=${EXCLFILE} ${RSYNCMINSIZE} ~/ ${SYNCSERVER}:./ >>~/.UserSync/UserSync.log  2>&1"
eval $RSYNCCMD
rsyncerr=$?
echo "" >>~/.UserSync/UserSync.log
[ "$RSYNCSPLITSIZE" = "0" ] || {
	echo "##### Syncro ${RSYNCMAXSIZE} #####" >>~/.UserSync/UserSync.log
	RSYNCCMD="${INSTALL_DIR}/bin/rsync3 --rsync-path=/usr/local/bin/rsync3 ${RSYNCOPTS} ${RSYNCRSH} ${RSYNCZ} ${RSYNCINPLACE} ${RSYNCTIMEOUT} ${RSYNCEXCLUDES} --exclude-from=${EXCLFILE} ${RSYNCMAXSIZE} ~/ ${SYNCSERVER}:./ >>~/.UserSync/UserSync.log  2>&1"
	eval $RSYNCCMD
	rsyncerr2=$?
	[ $rsyncerr -eq 0 ] && [ $rsyncerr2 -ne 0 ] && rsyncerr=$rsyncerr2
}
[ $rsyncerr -eq 0 ] || {
	if [ $rsyncerr -eq 24 ]
	then
	  # L'erreur 24 indique des fichiers qui ont ete supprimes de la source pendant le transfert, ca peut arriver souvent, on ignore.
	  [ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S :") "Ignoring Error 24 in errors" >>~/.UserSync/History.log
	else
	  DATEJOUR=$(date "+%Y%m%d")
	  [ -f ~/.UserSync/errs.${DATEJOUR}.log ] || {
		nblines=$(echo $(ls -1 ~/.UserSync/errs.* |wc -l))
		[ $nblines -gt 0 ] && {
			cat ~/.UserSync/errs.* > ~/.UserSync/errs.email.log
			echo  >> ~/.UserSync/errs.email.log
			echo "###########################"  >> ~/.UserSync/errs.email.log
			echo "###########################"  >> ~/.UserSync/errs.email.log
			echo  >> ~/.UserSync/errs.email.log
			cat ~/.UserSync/UserSync.log >> ~/.UserSync/errs.email.log
			emailAlert "Erreurs de synchro" "$(dirname ~/.UserSync)/.UserSync/errs.email.log" -file
			rm -f ~/.UserSync/errs.*
		}
		echo "Attention, les erreurs suivantes ont ete generees par rsync pour l'utilisateur $(id -un)." > ~/.UserSync/errs.${DATEJOUR}.log
		echo "Verifier les logs pour corriger le probleme." >> ~/.UserSync/errs.${DATEJOUR}.log
		echo "" >> ~/.UserSync/errs.${DATEJOUR}.log
		echo "$RSYNCERRNUMBERS"  >> ~/.UserSync/errs.${DATEJOUR}.log
		echo "" >> ~/.UserSync/errs.${DATEJOUR}.log
	  }
	  echo $(date "+%Y-%m-%d--%H:%M:%S :") Erreur $rsyncerr >> ~/.UserSync/errs.${DATEJOUR}.log
	fi
}

echo >>~/.UserSync/UserSync.log
echo "##### Sauvegarde des logs #####" >>~/.UserSync/UserSync.log
## Sauvegarde des logs
${INSTALL_DIR}/bin/rsync3 --rsync-path=/usr/local/bin/rsync3 -avzE --rsh=ssh --stats --timeout=10 ~/.UserSync ${SYNCSERVER}:. >>~/.UserSync/UserSync.log  2>&1
[ ${LOGHISTORY} -eq 1 ] && echo $(date "+%Y-%m-%d--%H:%M:%S : ")OK Fin >>~/.UserSync/History.log

[ ${LOGHISTORY} -eq 1 ] && {
	DATEJOUR=$(date "+%Y%m%d")
	[ -f ~/.UserSync/logs.${DATEJOUR}.log ] || rm -f ~/.UserSync/logs.*
	cat ~/.UserSync/UserSync.log >> ~/.UserSync/logs.${DATEJOUR}.log
	echo "###########################" >> ~/.UserSync/logs.${DATEJOUR}.log
	echo "###########################" >> ~/.UserSync/logs.${DATEJOUR}.log
}

rm -f ~/.UserSync/Semaphore

