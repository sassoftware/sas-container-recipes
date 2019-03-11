#!/bin/sh

SASDEPLOYID="viya"
SASHOME="/opt/sas/${SASDEPLOYID}/home"
SASCRYPTOHOME="${SASHOME}/SASSecurityCertificateFramework/bin"

# Set the cert/key paths for SLES or RHEL
if [ -d /etc/apache2/ssl.crt ]; then
  DEFAULTCERTPATH="/etc/apache2/ssl.crt"
  DEFAULTCSRPATH="/etc/apache2/ssl.csr"
  DEFAULTKEYPATH="/etc/apache2/ssl.key"
else
  DEFAULTCERTPATH="/etc/pki/tls/certs"
  DEFAULTCSRPATH="/etc/pki/tls/certs"
  DEFAULTKEYPATH="/etc/pki/tls/private"
fi

force=false
case "${1}" in
  --force)
    force="true";;
  force)
    force="true";;
  FORCE)
    force="true";;
  --FORCE)
    force="true";;
  -f)
    force="true";;
  *)
    force="false";;
esac

# Check if the httpd mod_ssl default cert path is present
if [ -f ${DEFAULTCERTPATH}/localhost.crt ]; then
   # Query the cert and determine the value of the basic constraint 'CA' (if there is one)
   CA=$(openssl x509 -noout -text -in ${DEFAULTCERTPATH}/localhost.crt|grep -e "^\\s*CA:\(TRUE\|FALSE\)"|tr -d '[:space:]'|sed 's/CA:\(TRUE\|FALSE\)/\1/')

   # If the CA basic constraint is FALSE, re-issue the cert without this constraint specified and restart httpd
   if [ "$CA" == "FALSE" ]; then
      echo "Default httpd cert detected. Issuing a new self-signed certificate."
      do_cert_refresh="true"
   elif [ $force == "true"  ]; then
      echo "Force flag passed. Issuing new self-signed certificate."
      do_cert_refresh="true"
   else
      do_cert_refresh="false"
   fi
else
   # If the cert directory doesn't exist, create it. Applies to SLES.
   if [ ! -d ${DEFAULTCERTPATH} ]; then
      mkdir -p ${DEFAULTCERTPATH}
   fi
   do_cert_refresh="true"
fi

if [ "$do_cert_refresh" == "true" ]; then
   # Back up current csr and cert
   [[ -f ${DEFAULTCSRPATH}/localhost.csr ]] && mv -f ${DEFAULTCSRPATH}/localhost.csr ${DEFAULTCSRPATH}/localhost.csr.orig 2>/dev/null
   [[ -f ${DEFAULTCERTPATH}/localhost.crt ]] && mv -f ${DEFAULTCERTPATH}/localhost.crt ${DEFAULTCERTPATH}/localhost.crt.orig

   # Generate a key if one doesn't exist
   if [ ! -d ${DEFAULTKEYPATH} ]; then
      echo "${DEFAULTKEYPATH} does not exist. Creating it."
      mkdir -p ${DEFAULTKEYPATH}
   fi
   if [ ! -f ${DEFAULTKEYPATH}/localhost.key ]; then
      echo "${DEFAULTKEYPATH}/localhost.key does not exist. Generating it."
      ${SASCRYPTOHOME}/sas-crypto-management genkey --out-file ${DEFAULTKEYPATH}/localhost.key --out-form pem
   fi

   # gather list of ip address, and create flags to pass to sas-crypto-management.
   ip_addrs=$(${SASHOME}/bin/sas-bootstrap-config network addresses --ipv4 --ipv6 --loopback|tr '\n' ' ')
   for ip_addr in $ip_addrs; do
      ip_addr_flags="$ip_addr_flags --san-ip $ip_addr"
   done

   # Generate CSR
   gencsr_cmd="${SASCRYPTOHOME}/sas-crypto-management \
      gencsr \
         --key ${DEFAULTKEYPATH}/localhost.key \
         --out-file ${DEFAULTCSRPATH}/localhost.csr \
         --out-form pem \
         --san-dns $(hostname -f) \
         --san-dns $(hostname) \
         --san-dns $(hostname -s) \
         --san-dns "*.$(hostname -f)" \
         --san-dns "*.$(hostname)" \
         --san-dns "*.$(hostname -s)" \
         --san-dns localhost"

   if [[ -n "${CASENV_CAS_VIRTUAL_HOST}" ]]; then
      gencsr_cmd+=" --san-dns $CASENV_CAS_VIRTUAL_HOST"
   fi
   gencsr_cmd+=" $ip_addr_flags"
   $gencsr_cmd

   # Self-sign CSR
   ${SASCRYPTOHOME}/sas-crypto-management \
      selfsign \
         --csr ${DEFAULTCSRPATH}/localhost.csr \
         --out-file ${DEFAULTCERTPATH}/localhost.crt \
         --out-form pem \
         --signing-key ${DEFAULTKEYPATH}/localhost.key

   # Restart httpd
   [[ -z $APACHE_CTL ]] && APACHE_CTL=$(which apachectl)
   $APACHE_CTL -k restart
else
   echo "Non-default httpd cert detected. Nothing to do."
fi
