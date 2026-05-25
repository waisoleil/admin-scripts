#!/bin/bash

#Varaibles globales
WEB_ROOT="/var/www/html"
BIND_CONFIG="/etc/bind/named.conf.local"
BIND_ZONE_DIR="/var/cache/bind"
APACHE_SSL_CERT="/etc/apache2/ssl/server.crt"
APACHE_SSL_KEY="/etc/apache2/ssl/server.key"
RESOLV_CONF="/etc/resolv.conf"

# Fonction : Vérifier les prérequis
check_prerequisites() {
    local tools=(
        "mariadb-server" "apache2" "php" "unzip" "bind9" "bind9utils" "bind9-doc" "dnsutils"
        "libapache2-mod-php" "php-mysql" "php-cli" "php-curl" "php-gd" "php-mbstring"
        "php-xml" "php-xmlrpc" "php8.2" "php8.2-cli" "php8.2-common" "php8.2-imap"
        "php8.2-redis" "php8.2-snmp" "php8.2-xml" "php8.2-mysqli" "php8.2-zip"
        "php8.2-mbstring" "php8.2-curl" "php8.2-intl" "php8.2-bcmath" "php8.2-soap"
    )

    # Vérifie si le fichier latest.zip existe dans le répertoire actuel
    if [ ! -f latest.zip ]; then
        echo "[Attention] latest.zip non trouvé."
        read -p "Voulez-vous télécharger latest.zip ? (O/n) : " response
        response=${response:-o}

        if [[ "$response" =~ ^[oO]$ ]]; then
            echo "Téléchargement de latest.zip..."
            wget https://wordpress.org/latest.zip
            if [ $? -ne 0 ]; then
                echo "[Erreur] Le téléchargement de latest.zip a échoué."
                exit 1
            else
                echo "[OK] latest.zip téléchargé avec succès."
            fi
        else
            echo "[Info] latest.zip ne sera pas téléchargé. Le script pourrait ne pas fonctionner correctement."
        fi
    else
        echo "[OK] latest.zip existe déjà."
    fi

    # Met à jour les dépôts et upgrade les packages existants
    apt update -y && apt upgrade -y

    for tool in "${tools[@]}"; do
        # Vérifie si le package est installé
        if ! dpkg-query -W -f='${Status}' "$tool" 2>/dev/null | grep -q "install ok installed"; then
            echo "[Attention] $tool n'est pas installé."
            # Demande si l'utilisateur souhaite installer le package
            read -p "Voulez-vous installer $tool ? (O/n) : " response
            response=${response:-o}  # Valeur par défaut "o"
            if [[ "$response" =~ ^[oO]$ ]]; then
                apt install -y "$tool"
                systemctl enable "$tool" 2>/dev/null || true
                systemctl start "$tool" 2>/dev/null || true
            else
                echo "[Info] $tool ne sera pas installé. Ce script pourrait ne pas fonctionner correctement."
            fi
        else
            echo "[OK] $tool est déjà installé."
        fi
    done
    
    # Activation des modules Apache
    echo "[Info] Activation des modules Apache..."
     a2enmod rewrite deflate headers ssl
    systemctl restart apache2
    
    # Sécurisation de MariaDB
    echo "[Info] Sécurisation de MariaDB..."
     mariadb-secure-installation
    
    # Génération du certificat SSL auto-signé si inexistant
    if [[ ! -f "$APACHE_SSL_CERT" || ! -f "$APACHE_SSL_KEY" ]]; then
        echo "[Info] Génération du certificat SSL auto-signé..."
         mkdir -p /etc/apache2/ssl
         chmod 700 /etc/apache2/ssl
         openssl genrsa -out "$APACHE_SSL_KEY" 2048
         openssl req -new -key "$APACHE_SSL_KEY" -out /etc/apache2/ssl/server.csr -subj "/CN=localhost"
         openssl x509 -req -days 365 -in /etc/apache2/ssl/server.csr -signkey "$APACHE_SSL_KEY" -out "$APACHE_SSL_CERT"
    fi
    
    # Configuration PHP pour WordPress
    echo "[Info] Configuration de PHP pour WordPress..."
     sed -i 's/^upload_max_filesize.*/upload_max_filesize = 2048M/' /etc/php/8.2/apache2/php.ini
     sed -i 's/^post_max_size.*/post_max_size = 2048M/' /etc/php/8.2/apache2/php.ini
     sed -i 's/^memory_limit.*/memory_limit = 2048M/' /etc/php/8.2/apache2/php.ini
     sed -i 's/^max_execution_time.*/max_execution_time = 300/' /etc/php/8.2/apache2/php.ini
     sed -i 's/^max_input_time.*/max_input_time = 300/' /etc/php/8.2/apache2/php.ini
    systemctl restart apache2
}

#Fonction : Création de la base de données
create_database() {
	local db_name=$1
	local db_user=$2
	local db_pass=$3

	echo "Entrez le mot de passe root MySQL :"
	read -s MYSQL_ROOT_PASS

	mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
	CREATE DATABASE IF NOT EXISTS $db_name;
	CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
	GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
	FLUSH PRIVILEGES;
EOF

	if [ $? -ne 0 ]; then
		echo "[Erreur] Échec de la création de la base de données ou de l'utilisateur MySQL."
		exit 1
	fi
}

# Fonction : Configurer DNS
setup_dns() {
	local site_name=$1
	
	# Demander à l'utilisateur de saisir l'adresse IP du serveur
	while true; do
		read -p "Entrez l'adresse IP du serveur : " ip_address
		
		# Vérifier si l'adresse IP est au bon format (IPv4)
		if [[ "$ip_address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
			# Vérifier si chaque octet est entre 0 et 255
			IFS='.' read -r -a octets <<< "$ip_address"
			if [[ ${octets[0]} -le 255 && ${octets[0]} -ge 0 && ${octets[1]} -le 255 && ${octets[1]} -ge 0 && ${octets[2]} -le 255 && ${octets[2]} -ge 0 && ${octets[3]} -le 255 && ${octets[3]} -ge 0 ]]; then
				break
			else
				echo "Adresse IP invalide. Les octets doivent être compris entre 0 et 255."
			fi
		else
			echo "Adresse IP invalide. Veuillez entrer une adresse IP au format correct (ex: 192.168.1.1)."
		fi
	done
	
	local zone_file="$BIND_ZONE_DIR/db.$site_name"
	
	# Créer un fichier de zone DNS configuré correctement
	cat > "$zone_file" <<EOF
;
; BIND data file for local web site $site_name
;
\$TTL    604800
@       IN      SOA     debian.$site_name. root.$site_name. (
       	                      2         ; Serial
               	         604800         ; Refresh
                       	  86400         ; Retry
                	2419200         ; Expire
                       	604800 )       ; Negative Cache TTL
;
@       IN      NS      debian.$site_name.
@       IN      A       $ip_address
debian  IN      A       $ip_address
WWW     IN      A       $ip_address
EOF

	# Ajouter la zone au fichier named.conf.local
	echo "zone \"$site_name\" IN {" >> "$BIND_CONFIG"
	echo "    type master;" >> "$BIND_CONFIG"
	echo "    file \"$zone_file\";" >> "$BIND_CONFIG"
	echo "    allow-update { key \"rndc-key\"; };" >> "$BIND_CONFIG"
	echo "};" >> "$BIND_CONFIG"
	echo -e "\n" >> "$BIND_CONFIG"

	# Vérifier et recharger Bind9
	named-checkzone "$site_name" "$zone_file"
	named-checkconf
	systemctl reload named.service

	# Modifier /etc/resolv.conf : Ajouter les lignes en haut
	tmpfile=$(mktemp)
	{
		echo "search $site_name"
		echo "nameserver $ip_address"
        echo -e "\n"
		cat "$RESOLV_CONF"
	} > "$tmpfile"
	mv "$tmpfile" "$RESOLV_CONF"
}

# Fonction : Configurer Apache
setup_apache() {
	local site_name=$1
	local site_root="$WEB_ROOT/$site_name"
	local apache_config="/etc/apache2/sites-available/$site_name.conf"
	local apache_conf="/etc/apache2/apache2.conf"

	# Vérification si ServerName 127.0.0.1 existe déjà dans apache2.conf
	if ! grep -q "^ServerName 127.0.0.1" "$apache_conf"; then
		# Si non, ajout de ServerName 127.0.0.1 à la fin du fichier apache2.conf
		echo "ServerName 127.0.0.1" >> "$apache_conf"
	fi

	cat > "$apache_config" <<EOF
<VirtualHost *:80>
   	ServerName $site_name
    	DocumentRoot $site_root
    	Redirect / https://$site_name/
</VirtualHost>

<VirtualHost *:443>
    	ServerName $site_name
    	DocumentRoot $site_root

    	SSLEngine on
    	SSLCertificateFile $APACHE_SSL_CERT
    	SSLCertificateKeyFile $APACHE_SSL_KEY

    	<Directory "$site_root">
        	AllowOverride All
        	Require all granted
    	</Directory>
</VirtualHost>
EOF

	# Vérification de la configuration Apache
  	apachectl configtest
  	a2ensite "$site_name"
  	systemctl reload apache2
}

#Fonction : Configurer WordPress
setup_wordpress() {
	local site_name=$1
  	local site_root="$WEB_ROOT/$site_name"
  	local db_name=$2
  	local db_user=$3
  	local db_pass=$4

  	# Définir les permissions pour éviter les erreurs
  	chown -R www-data:www-data "$site_root"
  	chmod -R 755 "$site_root"

  	# Créer le fichier wp-config.php
  	cat > "$site_root/wp-config.php" <<EOF
	<?php
	define('DB_NAME', '$db_name');
	define('DB_USER', '$db_user');
	define('DB_PASSWORD', '$db_pass');
	define('DB_HOST', 'localhost');
	define('DB_CHARSET', 'utf8');
	define('DB_COLLATE', '');
	\$table_prefix = 'wp_';
	define('WP_DEBUG', false);
	if ( !defined('ABSPATH') ) define('ABSPATH', dirname(__FILE__) . '/');
	require_once(ABSPATH . 'wp-settings.php');
EOF
}

#Fonction principale
main() {
	# Demander le nom du site
  	read -p "Entrez le nom du site (exemple : site.lan) : " site_name

  	if [ -z "$site_name" ]; then
    		echo "[Erreur] Vous devez spécifier un nom de site."
    		exit 1
 	fi

  	# Variables spécifiques au site
  	local site_root="$WEB_ROOT/$site_name"
  	local db_name="${site_name//./_}"
  	local db_user="${site_name//./_}admin"
  	local db_pass="Azertyuiop974+"

  	# Création du répertoire du site
  	mkdir -p "$site_root"
  	unzip latest.zip -d "$site_root"
  	mv "$site_root/wordpress/"* "$site_root"
  	rm -rf "$site_root/wordpress"

  	# Création de la base de données
  	create_database "$db_name" "$db_user" "$db_pass"

  	# Configuration DNS
  	setup_dns "$site_name"

  	# Configuration Apache
  	setup_apache "$site_name"

  	# Configurationr WordPress
  	setup_wordpress "$site_name" "$db_name" "$db_user" "$db_pass"

  	# Rappel des emplacements des fichiers
  	echo "[Succès] Le site $site_name a été configuré avec succès !"
  	echo "URL : https://$site_name"
  	echo "Répertoire du site : $site_root"
  	echo "Configuration Apache : /etc/apache2/sites-available/$site_name.conf"
  	echo "Fichier de zone DNS : $BIND_ZONE_DIR/db.$site_name"
  	echo "Fichier wp-config.php : $site_root/wp-config.php"
}

# Lancement du script
check_prerequisites
main