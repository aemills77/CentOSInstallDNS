#!/bin/bash

# CentOSInstallDNS.sh
# Author: Arthur "Damon" Mills
# Last Update: 06.03.2018
# Version: .2
# License: GPLv3

# Usage: Installs, configures, and deploys DNS Server (dnsmasq) on CentOS7 

# functions

function ipcheck() 
{
    local ADDR=$1
    
    # regex to check for valid IP address (0-255.0-255.0-255.0-255)
    if [[ "$ADDR" =~ ^([0-1]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([0-1]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([0-1]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([0-1]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
        # valid IP address
        return 0
    else
        # invalid IP address
        return 1
    fi
    # return ipcheck
}

function confdns()
{
    local IP=$1         # local server IP address
    local PRIME=$2      # primary DNS server
    local SECOND=$3     # secondary DNS server
    local LDOM=$4       # local domain
    local LOG=$5        # log file
    
    # creates a backup of /etc/dnsmasq.conf to /etc/dnsmasq.conf.orig
    sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    echo "Original /etc/dnsmasq.conf backed up to /etc/dnsmasq.conf.orig" | tee -a $LOG
    
    # write configuration to /etc/dnsmasq.conf file
    echo -n "Writing configuration to /etc/dnsmasq.conf..." | tee -a $LOG
    sudo sed -i -e "s/#domain-needed/domain-needed/g" /etc/dnsmasq.conf
    sudo sed -i -e "s/#bogus-priv/bogus-priv/g" /etc/dnsmasq.conf
    sudo sed -i -e "s/#strict-order/strict-order/g" /etc/dnsmasq.conf
    sudo sed -i -e "/#server=\/localnet\//a server=$PRIME" /etc/dnsmasq.conf
    sudo sed -i -e "/server=$PRIME/a server=$SECOND" /etc/dnsmasq.conf
    sudo sed -i -e "/#local=/a local=\/$LDOM\/" /etc/dnsmasq.conf
    sudo sed -i -e "s/#listen-address=/listen-address=$IP,127.0.0.1\n/g" /etc/dnsmasq.conf
    sudo sed -i -e "/#addn-hosts=/a addn-hosts=\/etc\/dnsmasq_static_hosts.conf" /etc/dnsmasq.conf
    # touch /etc/dnsmasq_statis_hosts.conf to create, in case one does not exist
    sudo touch /etc/dnsmasq_static_hosts.conf
    echo "SUCCESS" | tee -a $LOG
    
    return 0 # return confdns
}

function svcsdns()
{
    local LOG=$1    # log file

    # starts dnsmasq service and enables on boot
    echo -n "Enabling DNS (dnsmasq) service on boot..." | tee -a $LOG
    sudo systemctl start dnsmasq | tee -a $LOG
    sudo systemctl enable dnsmasq | tee -a $LOG
    echo "SUCCESS" | tee -a $LOG
    
    # adds DNS service entry to CentOS firewall
    echo -n "Creating DNS (dnsmasq) firewall entry..." | tee -a $LOG
    sudo firewall-cmd --add-service=dns --permanent
    sudo firewall-cmd --reload
    echo "SUCCESS" | tee -a $LOG

    return 0 # return svcsdns
}

# variables

MY_IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
INSTALL_LOG="install.$(date +%H%M%S)_$(date +%m%d%Y).log"

# main CentOSInstallDNS.sh

PROMPT="N"
# prompts user to continue prior to beginning install
echo "CentOS7 DNS (dnsmasq) server install/configuration." | tee -a $INSTALL_LOG
read -p "Continue (y/n)? " PROMPT
if [ ${PROMPT^^} = "Y" ] || [ ${PROMPT^^} = "YES" ]; then
    echo "Beginning installation..." | tee -a $INSTALL_LOG
    sudo su
else
    echo "Installation cancelled by user." | tee -a $INSTALL_LOG
    exit 1
fi

PROMPT="N"
# prompts user to enter local domain name, primary and secondary DNS server addresses
until [ ${PROMPT^^} = "Y" ] || [ ${PROMPT^^} = "YES" ]; do
    PRIMARY="0"
    SECONDARY="0"
    DOMAIN="example.net"
    until ipcheck $PRIMARY; do
        read -p "Primary DNS (8.8.8.8): " PRIMARY
        if [ -z "$PRIMARY" ]; then
            PRIMARY="8.8.8.8"
        fi
    done
    until ipcheck $SECONDARY; do
        read -p "Secondary DNS (8.8.4.4): " SECONDARY
        if [ -z "$SECONDARY" ]; then
            SECONDARY="8.8.4.4"
        fi        
    done
    read -p "Domain (example.net): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        DOMAIN="example.net"
    fi    
    echo -e "Primary DNS:\t ${PRIMARY}"
    echo -e "Secondary DNS:\t ${SECONDARY}"
    echo -e "Domain:\t\t ${DOMAIN}"
    read -p "Correct (y/n)? " PROMPT
    if [ -z $PROMPT ]; then
        PROMPT="N"
    fi
done

# records user choices in log file 
echo -e "Primary DNS:\t ${PRIMARY}" >> $INSTALL_LOG
echo -e "Secondary DNS:\t ${SECONDARY}" >> $INSTALL_LOG
echo -e "Domain:\t\t ${DOMAIN}" >> $INSTALL_LOG

# updates all yum packages and downloads dnsmasq package
echo "Updating all packages and downloading DNS server (dnsmasq)." | tee -a $INSTALL_LOG
sudo yum -y update >> $INSTALL_LOG
sudo yum -y install dnsmasq >> $INSTALL_LOG

confdns $MY_IP $PRIMARY $SECONDARY $DOMAIN $INSTALL_LOG
svcsdns $INSTALL_LOG

# finalize installation
echo "DNS (dnsmasq) server installation successful." | tee -a $INSTALL_LOG
echo "Add DNS records in /etc/hosts file to complete configuration." | tee -a $INSTALL_LOG

exit 0 # end CentOSInstallDNS.sh