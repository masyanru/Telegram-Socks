# Basic Dante Socks5 Setup, Debian

apt-get -y update
apt-get install make gcc

cd /usr/src

# get newest from http://www.inet.no/dante/download.html

wget http://www.inet.no/dante/files/dante-1.4.2.tar.gz

tar xvfz dante-1.4.2.tar.gz

cd dante-1.4.2

./configure \
--prefix=/usr \
--sysconfdir=/etc \
--localstatedir=/var \
--disable-client \
--without-libwrap \
--without-bsdauth \
--without-gssapi \
--without-krb5 \
--without-upnp \
--without-pam

make && make install

## if you want to use any of those auth methods, obviously remove their respective without statements
## docs can be found at http://www.inet.no/dante/doc/1.4.x/config/index.html

cat >/etc/init.d/sockd <<EOL
#! /bin/sh
### BEGIN INIT INFO
# Provides:          sockd
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start the dante SOCKS server.
# Description:       SOCKS (v4 and v5) proxy server daemon (sockd).
#                    This server allows clients to connect to it and
#                    request proxying of TCP or UDP network traffic
#                    with extensive configuration possibilities.
### END INIT INFO
#
# dante SOCKS server init.d file. Based on /etc/init.d/skeleton:
# Version:  @(#)skeleton  1.8  03-Mar-1998  miquels@cistron.nl 
# Via: https://gitorious.org/dante/pkg-debian

PATH=/sbin:/usr/sbin:/bin:/usr/bin
NAME=sockd
DAEMON=/usr/sbin/$NAME
DAEMON_ARGS="-D"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME
DESC="Dante SOCKS daemon"
CONFFILE=/etc/$NAME.conf

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

set -e

# This function makes sure that the Dante server can write to the pid-file.
touch_pidfile ()
{
  if [ -r $CONFFILE ]; then
    uid="`sed -n -e 's/[[:space:]]//g' -e 's/#.*//' -e '/^user\.privileged/{s/[^:]*://p;q;}' $CONFFILE`"
    if [ -n "$uid" ]; then
      touch $PIDFILE
      chown $uid $PIDFILE
    fi
  fi
}

case "$1" in
  start)
    if ! egrep -cve '^ *(#|$)' \
        -e '^(logoutput|user\.((not)?privileged|libwrap)):' \
        $CONFFILE > /dev/null
    then
        echo "Not starting $DESC: not configured."
        exit 0
    fi
    echo -n "Starting $DESC: "
    touch_pidfile
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
        || return 1
    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- \
        $DAEMON_ARGS \
        || return 2
    echo "$NAME."
    ;;
  stop)
    echo -n "Stopping $DESC: "
    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $NAME
    RETVAL="$?"
    [ "$RETVAL" = 2 ] && return 2
    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
    [ "$?" = 2 ] && return 2
    echo "$NAME."
    ;;
  reload|force-reload)
    #
    #   If the daemon can reload its config files on the fly
    #   for example by sending it SIGHUP, do it here.
    #
    #   If the daemon responds to changes in its config file
    #   directly anyway, make this a do-nothing entry.
    #
     echo "Reloading $DESC configuration files."
     start-stop-daemon --stop --signal 1 --quiet --pidfile \
        $PIDFILE --exec $DAEMON -- -D
  ;;
  restart)
    #
    #   If the "reload" option is implemented, move the "force-reload"
    #   option to the "reload" entry above. If not, "force-reload" is
    #   just the same as "restart".
    #
    echo -n "Restarting $DESC: "
    start-stop-daemon --stop --quiet --pidfile $PIDFILE --exec $DAEMON
    sleep 1
    touch_pidfile
    start-stop-daemon --start --quiet --pidfile $PIDFILE \
      --exec $DAEMON -- -D
    echo "$NAME."
    ;;
  status)
    status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
    ;;
  *)
    N=/etc/init.d/$NAME
    # echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
    echo "Usage: $N {start|stop|restart|status|force-reload}" >&2
    exit 1
    ;;
esac

exit 0
EOL

chmod +x /etc/init.d/sockd
update-rc.d sockd defaults

cat >/etc/sockd.conf <<EOL
# listen on... can be an IP or an interface
internal: eth0 port = 1080
# send out through... can be an IP or an interface
external: eth0

# for user auth run as this user
user.privileged:   root
# otherwise run as this user
user.unprivileged: nobody
# auth with user login, passwd
socksmethod:       username
# log to this file
logoutput:         /var/log/sockd.log

# allow everyone from everywhere so long as they auth, log errors
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error # connect disconnect iooperation
    socksmethod: username
}

# allow everyone from everywhere so long as they auth, log errors
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error # connect disconnect iooperation
    socksmethod: username
}

# generic pass statement for incoming connections/packets
# because something about no support for auth with bindreply udpreply ?
socks pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        command: bindreply udpreply
        log: error # connect disconnect iooperation
}
EOL

/etc/init.d/sockd start
##
# then make a user with no home or shell just for authing the proxy
# replace {PASSWORD} and {USER} with the password and the username
# useradd -M -s /usr/sbin/nologin -p $(openssl passwd -1 {PASSWORD}) {USER}
# -M avoids making a home, -s sets the shell to nologin so they get kicked instantly
# -p sets the password and pushes it through openssl because it needs to be encrypted in passwd
##
# Obviously full user accounts can be used, but this is raw UN/PW sent over cleartext
# so I would advise not using important accounts, or by using a different / multiple auth method(s)