#!/bin/bash
CLIENT_ID='1b3d5f7h-i9k0-99xf-425v-56477x8q62xy'
ISSUER_ID='9k8e1c2x-u8g5-71oi-131j-66242u5h10fu'
add-apt-repository -y ppa:ubuntu-enterprise-desktop/authd
apt update && apt upgrade -y
apt-get install -y authd
snap install authd-msentraid
sed -i "s|<CLIENT_ID>|$CLIENT_ID|g; s|<ISSUER_ID>|$ISSUER_ID|g"
/var/snap/authd-msentraid/current/broker.conf
echo 'ssh_allowed_suffixes = @uaadtest.onmicrosoft.com,@ubuntu.com' >>
/var/snap/authd-msentraid/current/broker.conf
touch /etc/ssh/sshd_config.d/authd.conf
echo "UsePAM yes" >> /etc/ssh/sshd_config.d/authd.conf
echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config.d/authd.conf
sed -i 's/^\(LOGIN_TIMEOUT\t\t\)[0-9]\+/\1360/' /etc/login.defs
mkdir -p /etc/authd/brokers.d/
cp /snap/authd-msentraid/current/conf/authd/msentraid.conf /etc/authd/brokers.d/
systemctl restart authd
snap restart authd-msentraid
systemctl restart ssh