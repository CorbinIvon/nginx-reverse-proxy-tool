# nginx-reverse-proxy-tool
A tool that makes passing services from localhost painless and work the first time! Just make sure that the host device forwards on port 80.

This tool will quickly create a http reverse proxy server. The script will run you through everything you need to do to get your service up and running.

## Usage
Run the script as root. root is usually needed to write to the /etc/nginx directory.

Currently supports the following services:
- [x] HTTP - Simple, non SSL service
- [ ] HTTPS - SSL service. Not yet implemented. Will use certbot and set file paths for the SSL certificates.

## Installation
1. Clone the repository
2. Run the script as root

