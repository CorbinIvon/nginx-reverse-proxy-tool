#!/bin/bash

# Detect -h or --help
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: nginx-rpt.sh"
    echo "Reverse Proxy Tool for Nginx"
    echo "Options:"
    echo "  -h, --help    Display this help message."
    exit 0
fi

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Detect nginx installation, prompt to install if not found
if [ ! -d /etc/nginx ]; then
    echo "Nginx is not installed. Would you like to install it? (y/n)"
    read -r install_nginx
    if [ "$install_nginx" == "y" ]; then
        # Detect OS
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; then
                apt install nginx
            elif [ "$ID" == "centos" ] || [ "$ID" == "fedora" ]; then
                yum install nginx
            else
                echo "Nginx installation is not supported on this OS. Please install Nginx manually."
                exit 1
            fi
        else
            echo "Could not determing OS. Please install Nginx manually."
            exit 1
        fi
    else
        echo "I'm sorry to hear that. Please install Nginx manually."
        exit 1
    fi
    # Verify installation
    if [ ! -d /etc/nginx ]; then
        echo "Nginx installation failed. Please install Nginx manually."
        exit 1
    fi
fi

# Detect /usr/bin/gum
if [ ! -f /usr/bin/gum ]; then
    echo "Gum is not installed. Please install it first."
    echo "https://github.com/charmbracelet/gum?tab=readme-ov-file#installation"
    exit 1
fi

# TODO: Add support for using https template.
# Certbot for setting up SSL and https
# Detect /usr/bin/certbot
if [ ! -f /usr/bin/certbot ]; then
    echo "Certbot is not installed. Would you like to install it? (y/n)"
    read -r install_certbot
    if [ "$install_certbot" == "y" ]; then
        # Detect OS
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; then
                apt install certbot
            elif [ "$ID" == "centos" ] || [ "$ID" == "fedora" ]; then
                yum install certbot
            else
                echo "Certbot installation is not supported on this OS. Please install Certbot manually."
                exit 1
            fi
        else
            echo "Could not determing OS. Please install Certbot manually."
            exit 1
        fi
    else
        echo "I'm sorry to hear that. Please install Certbot manually."
        exit 1
    fi
    # Verify installation
    if [ ! -f /usr/bin/certbot ]; then
        echo "Certbot installation failed. Please install Certbot manually."
        exit 1
    fi
fi

# Detect folder /etc/nginx/nginx-rpt
if [ ! -d /etc/nginx/nginx-rpt ]; then
    mkdir /etc/nginx/nginx-rpt
fi

# Detect file /etc/nginx/nginx-rpt/nginx-rpt.conf
nginx_rpt_configure () {
    default_domain_name="Example: YourDomain.com"
    default_listen_port=80
    default_dns_settings_url="https://your_provider/manage/your_domain_would_be_here.com/dns-settings"
    if [ -f /etc/nginx/nginx-rpt/nginx-rpt.conf ]; then
        source /etc/nginx/nginx-rpt/nginx-rpt.conf
    fi
    read -p "What is the default domain name? [$default_domain_name]: " domain_name
    if [ -z "$domain_name" ]; then
        domain_name=$default_domain_name
    fi
    read -p "What port should the reverse proxy be listening on? [$default_listen_port]: " service_host_port
    if [ -z "$service_host_port" ]; then
        service_host_port=80
    fi
    echo "Just a quick link for you when creating a new subdomain."
    read -p "What is the URL for your DNS settings? [$default_dns_settings_url]: " dns_settings_url
    if [ -z "$dns_settings_url" ]; then
        dns_settings_url=$default_dns_settings_url
    fi
    # Create /etc/nginx/nginx-rpt/nginx-rpt.conf. Only the 2 variables are stored in this file.
    echo "default_domain_name=$domain_name" > /etc/nginx/nginx-rpt/nginx-rpt.conf
    echo "default_listen_port=$service_host_port" >> /etc/nginx/nginx-rpt/nginx-rpt.conf
    echo "default_dns_settings_url=$dns_settings_url" >> /etc/nginx/nginx-rpt/nginx-rpt.conf
}

if [ ! -f /etc/nginx/nginx-rpt/nginx-rpt.conf ]; then
    nginx_rpt_configure
fi


# Create http profile in /etc/nginx/nginx-rpt/http.template
if [ ! -f /etc/nginx/nginx-rpt/http.template ]; then
    echo "server {" > /etc/nginx/nginx-rpt/http.template
    echo "    listen {{listen_port}};" >> /etc/nginx/nginx-rpt/http.template
    echo "    server_name {{server_name}};" >> /etc/nginx/nginx-rpt/http.template
    echo "" >> /etc/nginx/nginx-rpt/http.template
    echo "    location / {" >> /etc/nginx/nginx-rpt/http.template
    echo "        proxy_pass http://localhost:{{service_host_port}};" >> /etc/nginx/nginx-rpt/http.template
    echo "        proxy_set_header Host \$host;" >> /etc/nginx/nginx-rpt/http.template
    echo "        proxy_set_header X-Real-IP \$remote_addr;" >> /etc/nginx/nginx-rpt/http.template
    echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> /etc/nginx/nginx-rpt/http.template
    echo "        proxy_set_header X-Forwarded-Proto \$scheme;" >> /etc/nginx/nginx-rpt/http.template
    echo "    }" >> /etc/nginx/nginx-rpt/http.template
    echo "}" >> /etc/nginx/nginx-rpt/http.template
fi

while true; do
    if [ ! -f /usr/bin/gum ]; then
        $non_bash_user_choice=""
        while [[ ! $non_bash_user_choice =~ ^[1-5]$ ]]; do
            read -p "Invalid choice. Choose:\n1)Enable / Disable, 2)Create, 3)Delete, 4)Exit: " non_bash_user_choice
        done
        case $non_bash_user_choice in
            1)user_choice="Enable / Disable";;
            2)user_choice="Create";;
            3)user_choice="Delete";;
            4)user_choice="Exit";;
        esac
    else
        user_choice=$(/usr/bin/gum choose "Enable / Disable" "Create" "Delete" "Configure" "Exit")
    fi
    case $user_choice in
        "Create")
            echo "-- Creating a new reverse proxy configuration..."
            # Choose from the /etc/nginx/nginx-rpt/*.template files
            if [ ! -f /usr/bin/gum ]; then
                $template_file=""
                echo $(ls /etc/nginx/nginx-rpt/*.template)
                while [[ ! -f /etc/nginx/nginx-rpt/$template_file ]]; do
                    read -p "Choose a template file: " template_file
                done
            else
                template_file=$(/usr/bin/gum choose $(ls /etc/nginx/nginx-rpt/*.template | xargs -n 1 basename))
            fi
            # Should be http.*
            if [[ $template_file == http.* ]]; then
                source /etc/nginx/nginx-rpt/nginx-rpt.conf
                read -p "Enter the subdomain name: " subdomain_name
                read -p "Port that is hosting the service via localhost: " service_host_port
                # Ask if it should use the default domain name
                read -p "Domain Name [$default_domain_name]: " used_domain_name
                if [ -z "$used_domain_name" ]; then
                    used_domain_name=$default_domain_name
                fi
                # Ask if it should use the default listen port
                read -p "Listen Port [$default_listen_port]: " used_listen_port
                if [ -z "$used_listen_port" ]; then
                    used_listen_port=$default_listen_port
                fi
                cp /etc/nginx/nginx-rpt/$template_file /etc/nginx/sites-available/http.$subdomain_name.$used_domain_name
                sed -i "s/{{server_name}}/$subdomain_name.$used_domain_name/" /etc/nginx/sites-available/http.$subdomain_name.$used_domain_name
                sed -i "s/{{listen_port}}/$used_listen_port/" /etc/nginx/sites-available/http.$subdomain_name.$used_domain_name
                sed -i "s/{{service_host_port}}/$service_host_port/" /etc/nginx/sites-available/http.$subdomain_name.$used_domain_name
                ln -s /etc/nginx/sites-available/http.$subdomain_name.$used_domain_name /etc/nginx/sites-enabled/http.$subdomain_name.$used_domain_name
            fi
            # Test nginx file before restarting. If test fails, do not restart.
            nginx -t
            if [ $? -eq 0 ]; then
                echo "nginx config pass."
                systemctl restart nginx
                if [ $? -eq 0 ]; then
                    echo "Nginx restarted."
                    echo "-- Please remember to configure your DNS settings. --"
                    echo "DNS settings URL: $default_dns_settings_url"
                else
                    echo "Failed to restart nginx."
                    echo "Please check the configuration file: /var/log/nginx/error.log"
                fi
            else
                echo "nginx config fail."
                echo "Please check the configuration file: /var/log/nginx/error.log"
            fi
            ;;
        "Enable / Disable")
            echo "-- Enabling / Disabling an existing reverse proxy configuration..."
            # Choose from /etc/nginx/sites-available/*
            if [ ! -f /usr/bin/gum ]; then
                $server_name=""
                available_sites=$(ls /etc/nginx/sites-available/*)
                enabled_sites=$(ls /etc/nginx/sites-enabled/*)
                # Subtract enabled_sites from available_sites, add [ENABLED] or [DISABLED] if site is enabled or disabled
                for site in $available_sites; do
                    if [[ $enabled_sites == *"$site"* ]]; then
                        echo " [ENABLED] | $site"
                    else
                        echo "[DISABLED] | $site"
                    fi
                done
                while [[ ! -f /etc/nginx/sites-available/$server_name ]]; do
                    read -p "Choose a server name: " server_name
                done
            else
                available_sites=$(ls /etc/nginx/sites-available/* | xargs -n 1 basename)
                enabled_sites=$(ls /etc/nginx/sites-enabled/* | xargs -n 1 basename)
                # Subtract enabled_sites from available_sites, add [ENABLED] or [DISABLED] if site is enabled or disabled
                gum_array=()
                declare -a gum_array
                for site in $available_sites; do
                    if [[ " $enabled_sites " == *"$site"* ]]; then
                        gum_array+=(" [ENABLED] | $site")
                    else
                        gum_array+=("[DISABLED] | $site")
                    fi
                done
                server_name=$(gum choose <<< "$(printf "%s\n" "${gum_array[@]}")")
                # Strip [ENABLED] or [DISABLED] from server_name
                server_name=$(echo $server_name | sed 's/\[ENABLED\]\ |\ //g' | sed 's/\[DISABLED\]\ |\ //g')
            fi
            # read -p "Enter the server name: " server_name
            if [ -f /etc/nginx/sites-available/$server_name ]; then
                if [ -f /etc/nginx/sites-enabled/$server_name ]; then
                    rm /etc/nginx/sites-enabled/$server_name
                    systemctl restart nginx
                    echo "Disabled $server_name."
                else
                    ln -s /etc/nginx/sites-available/$server_name /etc/nginx/sites-enabled/$server_name
                    systemctl restart nginx
                    echo "Enabled $server_name."
                fi
            else
                echo "Reverse proxy configuration not found."
                exit 1
            fi
            ;;
        "Delete")
            echo "-- Deleting an existing reverse proxy configuration..."
            # Choose from /etc/nginx/sites-available/*
            if [ ! -f /usr/bin/gum ]; then
                $server_name=""
                echo $(ls /etc/nginx/sites-available/*)
                while [[ ! -f /etc/nginx/sites-available/$server_name ]]; do
                    read -p "Choose a server name: " server_name
                done
            else
                server_name=$(/usr/bin/gum choose $(ls /etc/nginx/sites-available/* | xargs -n 1 basename))
            fi
            if [ -f /etc/nginx/sites-available/$server_name ]; then
                rm -f /etc/nginx/sites-available/$server_name
                rm -f /etc/nginx/sites-enabled/$server_name
                systemctl restart nginx
                echo "Deleted $server_name."
            else
                echo "Reverse proxy configuration not found."
                exit 1
            fi
            ;;
        "Configure")
            echo "-- Configuring /etc/nginx/nginx-rpt/nginx-rpt.conf..."
            nginx_rpt_configure
            ;;
        "Exit")
            echo "Exiting..."
            exit 0
            ;;
    esac
done