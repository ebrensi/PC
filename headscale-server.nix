{
  config,
  pkgs,
  ...
}: {
  # Headscale - self-hosted Tailscale control server
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    settings = {
      # see https://github.com/juanfont/headscale/blob/main/config-example.yaml

      server_url = "http://73.15.57.26:8080"; # Your public IP
      listen_addr = "0.0.0.0:8080";

      # Networking settings
      prefixes.v4 = "100.64.0.0/10"; # Tailscale IPv4 range

      # DNS settings
      dns = {
        base_domain = "home.arpa";
        nameservers.global = ["1.1.1.1" "8.8.8.8"];
        magic_dns = true;
      };
    };
  };

  # Security for headscale service
  #  Monitoring options:

  # 1. Monitor Headscale Logs (Real-time)
  # journalctl -u headscale -f                    # Follow logs
  # journalctl -u headscale --since "1 hour ago"  # Last hour
  # journalctl -u headscale | grep -i error       # Errors only

  # 2. Monitor Active Connections (Live)
  # # Watch connections to port 8080
  # watch -n 1 'ss -tn state established "( dport = :8080 or sport = :8080 )"'

  # # Show all connections with IP addresses
  # ss -tnp | grep :8080

  # Then monitor with:
  # journalctl -k -f | grep HEADSCALE  # Kernel logs for port 8080

  # 4. Packet Capture (Deep Inspection)
  # # Capture all traffic on port 8080
  # sudo tcpdump -i any port 8080 -n

  # # Save to file for later analysis
  # sudo tcpdump -i any port 8080 -w /tmp/port8080.pcap

  # Open firewall for headscale
  networking.firewall = {
    allowedTCPPorts = [8080];
    # Log dropped packets (potential attacks)
    # logRefusedPackets = true;

    # Custom rules to log accepted connections on 8080
    extraCommands = ''
          iptables -A INPUT -p tcp --dport 8080 -j LOG --log-prefix "HEADSCALE: "
      --log-level 4
    '';
  };

  # Rate limiting with fail2ban
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";

    # Ignore Tailscale/Headscale IP range to prevent banning trusted devices
    ignoreIP = [
      "127.0.0.0/8" # localhost
      "192.168.0.0/16" # local network
      "100.64.0.0/10" # Tailscale/Headscale range
    ];

    jails = {
      headscale = ''
        enabled = true
        filter = headscale
        port = 8080
        logpath = /var/log/headscale/headscale.log
        maxretry = 10
        findtime = 600
        bantime = 3600
      '';
    };
  };

  # Fail2ban filter for headscale
  environment.etc."fail2ban/filter.d/headscale.conf" = {
    text = ''
      [Definition]
      failregex = ^.*Failed authentication.*from <HOST>.*$
                  ^.*Invalid key.*from <HOST>.*$
      ignoreregex =
    '';
  };

  # Headscale monitoring script
  # Usage: headscale-monitor
  # Displays real-time monitoring dashboard for port 8080
  environment.systemPackages = [
    (pkgs.writeScriptBin "headscale-monitor" ''
      #!/usr/bin/env bash

      # Colors
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      MAGENTA='\033[0;35m'
      CYAN='\033[0;36m'
      NC='\033[0m' # No Color
      BOLD='\033[1m'

      # Thresholds for alerts
      HIGH_CONN_THRESHOLD=50  # Alert if IP has >50 connections

      # Function to display header
      show_header() {
        clear
        echo -e "''${BOLD}''${CYAN}╔═══════════════════════════════════════════════════════════════════╗''${NC}"
        echo -e "''${BOLD}''${CYAN}║          HEADSCALE PORT 8080 MONITORING DASHBOARD                 ║''${NC}"
        echo -e "''${BOLD}''${CYAN}╚═══════════════════════════════════════════════════════════════════╝''${NC}"
        echo -e "''${BOLD}Updated: $(date '+%Y-%m-%d %H:%M:%S')''${NC}\n"
      }

      # Function to show fail2ban status
      show_fail2ban() {
        echo -e "''${BOLD}''${BLUE}┌─ FAIL2BAN STATUS''${NC}"

        local status=$(sudo fail2ban-client status headscale 2>/dev/null)
        local banned=$(echo "$status" | grep "Currently banned:" | awk '{print $4}')
        local total_banned=$(echo "$status" | grep "Total banned:" | awk '{print $4}')

        if [ "$banned" = "0" ]; then
          echo -e "''${GREEN}✓ Currently banned: 0''${NC}"
        else
          echo -e "''${RED}⚠ Currently banned: $banned''${NC}"
        fi
        echo -e "  Total banned (all time): $total_banned"

        # Show banned IPs if any
        local banned_ips=$(echo "$status" | grep "Banned IP list:" | cut -d: -f2)
        if [ -n "$banned_ips" ] && [ "$banned_ips" != " " ]; then
          echo -e "  ''${RED}Banned IPs: $banned_ips''${NC}"
        fi
        echo ""
      }

      # Function to show connection statistics
      show_stats() {
        echo -e "''${BOLD}''${BLUE}┌─ CONNECTION STATISTICS (Last 24 Hours)''${NC}"

        local total_conns=$(journalctl -k --since "24 hours ago" 2>/dev/null | grep HEADSCALE | wc -l)
        local unique_ips=$(journalctl -k --since "24 hours ago" 2>/dev/null | grep HEADSCALE | grep -oP 'SRC=\K[^ ]+' | sort -u | wc -l)
        local conns_last_hour=$(journalctl -k --since "1 hour ago" 2>/dev/null | grep HEADSCALE | wc -l)

        echo -e "  Total connections: ''${BOLD}$total_conns''${NC}"
        echo -e "  Unique IP addresses: ''${BOLD}$unique_ips''${NC}"
        echo -e "  Connections (last hour): ''${BOLD}$conns_last_hour''${NC}"
        echo ""
      }

      # Function to show top connecting IPs
      show_top_ips() {
        echo -e "''${BOLD}''${BLUE}┌─ TOP 10 CONNECTING IPs (Last 24 Hours)''${NC}"
        echo -e "  ''${BOLD}Count  IP Address''${NC}"

        journalctl -k --since "24 hours ago" 2>/dev/null | \
          grep HEADSCALE | \
          grep -oP 'SRC=\K[^ ]+' | \
          sort | uniq -c | sort -rn | head -10 | \
          while read count ip; do
            if [ "$count" -gt "$HIGH_CONN_THRESHOLD" ]; then
              echo -e "  ''${RED}$count\t$ip ⚠''${NC}"
            elif [ "$count" -gt 20 ]; then
              echo -e "  ''${YELLOW}$count\t$ip''${NC}"
            else
              echo -e "  ''${GREEN}$count\t$ip''${NC}"
            fi
          done
        echo ""
      }

      # Function to show recent connections
      show_recent() {
        echo -e "''${BOLD}''${BLUE}┌─ RECENT CONNECTIONS (Last 10)''${NC}"
        echo -e "  ''${BOLD}Time       Source IP          Action''${NC}"

        journalctl -k --since "5 minutes ago" 2>/dev/null | \
          grep HEADSCALE | \
          tail -10 | \
          while IFS= read -r line; do
            local timestamp=$(echo "$line" | awk '{print $3}')
            local src_ip=$(echo "$line" | grep -oP 'SRC=\K[^ ]+')
            local flags=$(echo "$line" | grep -oP '(SYN|ACK|FIN|RST|PSH)' | tr '\n' ',' | sed 's/,$//')

            if echo "$flags" | grep -q "RST"; then
              echo -e "  ''${RED}$timestamp $src_ip  $flags (Reset)''${NC}"
            elif echo "$flags" | grep -q "SYN"; then
              echo -e "  ''${YELLOW}$timestamp $src_ip  $flags (New)''${NC}"
            else
              echo -e "  ''${GREEN}$timestamp $src_ip  $flags''${NC}"
            fi
          done
        echo ""
      }

      # Function to show headscale service status
      show_service_status() {
        echo -e "''${BOLD}''${BLUE}┌─ HEADSCALE SERVICE''${NC}"

        if systemctl is-active --quiet headscale; then
          echo -e "  Status: ''${GREEN}✓ Running''${NC}"
          local uptime=$(systemctl show headscale --property=ActiveEnterTimestamp --value)
          echo -e "  Started: $uptime"
        else
          echo -e "  Status: ''${RED}✗ Not Running''${NC}"
        fi
        echo ""
      }

      # Function to show alerts
      show_alerts() {
        echo -e "''${BOLD}''${BLUE}┌─ ALERTS''${NC}"

        local alerts=0

        # Check for high-frequency IPs
        local high_freq=$(journalctl -k --since "1 hour ago" 2>/dev/null | \
          grep HEADSCALE | grep -oP 'SRC=\K[^ ]+' | \
          sort | uniq -c | sort -rn | head -1 | awk '{print $1}')

        if [ "$high_freq" -gt 100 ]; then
          echo -e "  ''${RED}⚠ High connection frequency detected: $high_freq connections from single IP''${NC}"
          alerts=$((alerts + 1))
        fi

        # Check for service errors
        local errors=$(journalctl -u headscale --since "1 hour ago" 2>/dev/null | grep -i error | wc -l)
        if [ "$errors" -gt 0 ]; then
          echo -e "  ''${RED}⚠ $errors errors in headscale logs (last hour)''${NC}"
          alerts=$((alerts + 1))
        fi

        if [ "$alerts" -eq 0 ]; then
          echo -e "  ''${GREEN}✓ No alerts''${NC}"
        fi
        echo ""
      }

      # Main monitoring loop
      echo -e "''${CYAN}Starting Headscale Monitor... (Press Ctrl+C to exit)''${NC}\n"
      sleep 1

      while true; do
        show_header
        show_service_status
        show_fail2ban
        show_stats
        show_alerts
        show_top_ips
        show_recent

        echo -e "''${BOLD}''${CYAN}Press Ctrl+C to exit | Auto-refresh in 5 seconds...''${NC}"

        sleep 5
      done
    '')
  ];
}
