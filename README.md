# WAF – Web Application Firewall (WAF Guide)

This repository contains the project report and resources used to build and test a simple Web Application Firewall (WAF) lab using AlmaLinux, BunkerWeb (WAF), Apache (virtual hosts) and Bind (DNS). The work was completed as part of the "Tópicos de Engenharia Informática" coursework.

Authors:
- Martinho José Novo Caeiro - 23917
- Paulo António Tavares Abade - 23919  

Institution:
- Instituto Politécnico de Beja — Escola Superior de Tecnologia e Gestão 

---

## Contents of this repository

- Relatorio.tex — LaTeX source of the project report (English/Portuguese content).
- Recursos/ — Images, logos and the BibTeX file referenced by the LaTeX report (e.g., screenshots of DNS, WAF UI and Nikto tests).
  - Recursos/referencias.bib
  - Recursos/Logos/
  - Various screenshots used in the report.

---

## Project summary

The lab demonstrates how to:

- Install and configure AlmaLinux virtual machines (Server and WAF).
- Configure DNS (Bind) and create forward zones for example domains.
- Configure multiple Apache Virtual Hosts to serve different sites from the same server.
- Install and configure a WAF (BunkerWeb on Nginx) in front of the web server to filter and protect web traffic.
- Test the WAF effectiveness using Kali Linux and the Nikto scanner.

Example domains used in the lab:
- trinta.org
- 3emfrente.eu
- the.com
- tei.pt (contains server and waf host records)

Example IPs (lab/internal):
- Server and WAF: 192.168.1.100
- Apache host interface: 192.168.1.101

> Note: These IPs and credentials are for lab/demo purposes only.

---

## Quick reproduction guide

Below is a condensed sequence of actions used in the project. Adjust details (IPs, hostnames, passwords) to your environment.

### VM and system preparation
- Create two AlmaLinux VMs: "server" and "waf".
- Example VM resources (lab): 1 GB RAM, 2 vCPUs, 8 GB disk (with partitions /boot, swap, /).
- Use bridged network so VMs are reachable on the same LAN.

### Common system changes (lab only — not recommended for production)
- Disable firewalld (lab convenience):  
  sudo systemctl disable --now firewalld
- Disable SELinux (lab convenience): edit `/etc/selinux/config` and set:  
  SELINUX=disabled  
  Reboot if needed.

### Packages to install

Server (Apache + DNS):
- nano, whois, bind, bind-utils, httpd

WAF (Nginx + BunkerWeb):
- nano, nginx, epel-release, bunkerweb

Example commands (run on respective VMs):
- On server:
  sudo yum install -y nano whois bind bind-utils httpd
- On WAF:
  sudo yum install -y epel-release
  # Configure nginx repo (see report), then:
  sudo yum install -y nginx-1.26.3
  # Add BunkerWeb repo & install:
  curl -s https://repo.bunkerweb.io/install/script.rpm.sh | sudo bash
  sudo yum check-update
  sudo yum install -y bunkerweb-1.6.1
  # Prevent auto-upgrades (optional)
  sudo yum versionlock add nginx
  sudo yum versionlock add bunkerweb

### Bind (DNS) configuration (server)
- Edit `/etc/named.conf`:
  - allow queries and listen-on set appropriately (lab used `any;`).
  - Define forward zones for each example domain, e.g.:
    ```
    zone "trinta.org" {
      type master;
      file "/var/named/trinta.org.hosts";
    };
    ```
- Create zone files such as `/var/named/trinta.org.hosts` with SOA, NS and A records.
- Restart named:
  sudo systemctl enable --now named
  sudo systemctl restart named

### Apache Virtual Hosts
- Create users/directories for each site (e.g., /home/trinta.org).
- Edit Apache config (or add vhost files) to add VirtualHost blocks listening on the server IP and port 80. Example:
  ```
  <VirtualHost 192.168.1.101:80>
    DocumentRoot "/home/trinta.org"
    ServerName www1.trinta.org
    ServerAlias trinta.org
    <Directory "/home/trinta.org">
      Options Indexes FollowSymLinks
      AllowOverride All
      Require method GET POST OPTIONS
    </Directory>
  </VirtualHost>
  ```
- Add simple `index.html` pages into each site's DocumentRoot.
- Restart httpd:
  sudo systemctl enable --now httpd
  sudo systemctl restart httpd

### WAF (BunkerWeb) setup
- Configure `/etc/yum.repos.d/nginx.repo` with nginx stable/mainline repositories (see report for snippet).
- Install nginx and bunkerweb (commands shown above).
- Access the WAF web setup: https://192.168.1.100/setup
  - Lab initial root password used in the report: `Tei1234.` (change immediately in real deployments)
- WAF configuration steps (via web UI):
  - Create a new Service for each site (e.g., www1.trinta.org) and point to the backend server IP.
  - Add blacklisted IPs (e.g., Kali IP for demonstration).
  - Enable Antibot (Captcha/Recaptcha).
  - Block selected countries if desired.

### Testing (Kali Linux)
- Use Nikto to scan the service with and without WAF protections and compare results. Example:
  nikto -h https://www1.trinta.org
- Observe behavior changes when WAF protections are active (redirects to Captcha, blocked requests, IP blacklisting, fewer reported issues).

---

## Important notes and warnings

- Disabling firewall or SELinux reduces system security. The report disables them for lab convenience only. Do not do this in production.
- Do not use lab passwords (e.g., '1234', 'Tei1234.') in real systems. Use strong, unique passwords and proper TLS certificates.
- The guide uses private/example IPs and domain names for an isolated lab. Adjust network and DNS settings for your environment and security policy.
- BunkerWeb is a commercial/third-party product — follow vendor documentation and licensing.

---

## Building the PDF report

If you want to compile the LaTeX report:

- Ensure TeXLive (or similar) and biber are installed.
- From the repository root:
  pdflatex Relatorio.tex
  biber Relatorio
  pdflatex Relatorio.tex
  pdflatex Relatorio.tex

Make sure the `Recursos/` images and `Recursos/referencias.bib` are present and paths in the .tex are correct.

---

## References & resources

See the bibliography and the "Relatorio.tex" file for citations and detailed steps/screenshots. The `Recursos/` folder contains the images referenced in the report.
