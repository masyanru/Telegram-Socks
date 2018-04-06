# Basic Dante Socks5 Setup

apt-get -y update
wget http://ppa.launchpad.net/dajhorn/dante/ubuntu/pool/main/d/dante/dante-server_1.4.1-1_amd64.deb
apt-get install gdebi-core
dpkg -i dante-server_1.4.1-1_amd64.deb


cat >/etc/danted.conf <<EOL
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
# logoutput:         /var/log/sockd.log

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

service danted start