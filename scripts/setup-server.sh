#######################
# Setup rudder server #
#######################
setup_server() {

  # install via package manager only
  if [ -z "${PM}" ]
  then
    echo "Sorry your System is not *yet* supported !"
    exit 4
  fi

  # TODO detect supported OS
  # echo "Sorry your System is not supported by Rudder Server !"
  # exit 5

  $local SERVER_HOSTNAME=`hostname`
  $local DEMOSAMPLE="no"
  $local LDAPRESET="yes"
  $local INITPRORESET="yes"
  # TODO detect
  [ -z "${ALLOWEDNETWORK}" ] && $local ALLOWEDNETWORK='127.0.0.1/24'

  # debian / jdk6
  if [ "${PM}" = "apt" ]
  then
    cat << EOF | debconf-set-selections
sun-java6-bin   shared/accepted-sun-dlj-v1-1    boolean true
sun-java6-jre   shared/accepted-sun-dlj-v1-1    boolean true
EOF
  fi

  # install
  ${PM_INSTALL} rudder-server-root

  # hacks
  #######
  # None at first

  # Initialize Rudder
  /opt/rudder/bin/rudder-init.sh ${SERVER_HOSTNAME} ${DEMOSAMPLE} ${LDAPRESET} ${INITPRORESET} ${ALLOWEDNETWORK} < /dev/null > /dev/null 2>&1
}

upgrade_server() {
  # Upgrade via package manager only
  if [ -z "${PM}" ]
  then
    echo "Sorry your System is not *yet* supported !"
    exit 4
  fi

  # Upgrade
  if [ "${PM}" = "apt" ]
  then
    ${PM_UPGRADE} rudder-server-root ncf ncf-api-virtualenv
  else
    ${PM_UPGRADE} "rudder-*" "ncf"
  fi

  /etc/init.d/rudder-jetty restart
}

upgrade_techniques() {
  cd /var/rudder/configuration-repository
  cp -a /opt/rudder/share/techniques/* techniques/
  git add -u techniques
  git add techniques
  git commit -m "Technique upgrade to version ${RUDDER_VERSION}"
  curl -s -f -k "https://localhost/rudder/api/techniqueLibrary/reload"
  ehco ""
}
