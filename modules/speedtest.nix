{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.speedtest;
in
{
  options.programs.speedtest = {
    enable = mkEnableOption "speedtest script with GPS-based location detection";

    package = mkOption {
      type = types.package;
      default = pkgs.writeShellScriptBin "speedtesthelper" ''
        echo "## Speed Test - $(date)"
        echo
        
        # Get basic network info (IP and ISP only)
        location_data=$(curl -s "https://ipinfo.io")
        if [ -n "$location_data" ]; then
          ip=$(echo "$location_data" | grep '"ip"' | cut -d'"' -f4)
          org=$(echo "$location_data" | grep '"org"' | cut -d'"' -f4)
          timezone=$(echo "$location_data" | grep '"timezone"' | cut -d'"' -f4)
          fallback_loc=$(echo "$location_data" | grep '"loc"' | cut -d'"' -f4)
          
          echo "**IP Address:** $ip"
          [ -n "$org" ] && echo "**ISP/Provider:** $org"
          [ -n "$timezone" ] && echo "**Timezone:** $timezone"
        fi
        
        # Get GPS coordinates - prioritize CoreLocationCLI on macOS
        gps_coords=""
        if [[ "$(uname)" == "Darwin" ]] && command -v CoreLocationCLI >/dev/null 2>&1; then
          echo "**Getting precise GPS location...**"
          core_loc=$(CoreLocationCLI -once -format "%latitude,%longitude")
          if [ -n "$core_loc" ] && [[ "$core_loc" != *"Error"* ]]; then
            gps_coords="$core_loc"
            echo "**GPS Coordinates:** [$gps_coords](https://maps.google.com/maps?q=$gps_coords)"
          fi
        fi
        
        # Fallback to ipinfo.io coordinates if CoreLocationCLI failed or unavailable
        if [ -z "$gps_coords" ] && [ -n "$fallback_loc" ]; then
          gps_coords="$fallback_loc"
          echo "**GPS Coordinates:** [$gps_coords](https://maps.google.com/maps?q=$gps_coords)"
        fi
        
        # Get full address from GPS coordinates using reverse geocoding
        if [ -n "$gps_coords" ]; then
          echo "**Resolving address from GPS coordinates...**"
          # Handle both comma-separated and space-separated coordinates
          if [[ "$gps_coords" == *","* ]]; then
            lat=$(echo "$gps_coords" | cut -d',' -f1)
            lon=$(echo "$gps_coords" | cut -d',' -f2)
          else
            lat=$(echo "$gps_coords" | awk '{print $1}')
            lon=$(echo "$gps_coords" | awk '{print $2}')
          fi
          
          # Use Nominatim reverse geocoding API (OpenStreetMap) with English language preference
          reverse_geo=$(curl -s "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1&zoom=18&accept-language=en")
          
          if [ -n "$reverse_geo" ]; then
            # Extract address components
            display_name=$(echo "$reverse_geo" | grep '"display_name"' | sed 's/.*"display_name": *"\([^"]*\)".*/\1/')
            house_number=$(echo "$reverse_geo" | grep '"house_number"' | sed 's/.*"house_number": *"\([^"]*\)".*/\1/')
            road=$(echo "$reverse_geo" | grep '"road"' | sed 's/.*"road": *"\([^"]*\)".*/\1/')
            suburb=$(echo "$reverse_geo" | grep '"suburb"' | sed 's/.*"suburb": *"\([^"]*\)".*/\1/')
            city=$(echo "$reverse_geo" | grep '"city"' | sed 's/.*"city": *"\([^"]*\)".*/\1/')
            town=$(echo "$reverse_geo" | grep '"town"' | sed 's/.*"town": *"\([^"]*\)".*/\1/')
            state=$(echo "$reverse_geo" | grep '"state"' | sed 's/.*"state": *"\([^"]*\)".*/\1/')
            postcode=$(echo "$reverse_geo" | grep '"postcode"' | sed 's/.*"postcode": *"\([^"]*\)".*/\1/')
            country=$(echo "$reverse_geo" | grep '"country"' | sed 's/.*"country": *"\([^"]*\)".*/\1/')
            
            # Build formatted address
            if [ -n "$display_name" ]; then
              echo "**Estimated Address (GPS-based):** $display_name"
              
              # Show individual components if available
              [ -n "$house_number" ] && [ -n "$road" ] && echo "**Street:** $house_number $road"
              [ -n "$suburb" ] && echo "**Suburb/District:** $suburb"
              
              # Prefer city over town
              location=""
              if [ -n "$city" ]; then
                location="$city"
              elif [ -n "$town" ]; then
                location="$town"
              fi
              [ -n "$location" ] && [ -n "$state" ] && echo "**City/State:** $location, $state"
              
              [ -n "$postcode" ] && echo "**Postal Code:** $postcode"
              [ -n "$country" ] && echo "**Country:** $country"
            else
              echo "**Location:** Unable to resolve address from GPS coordinates"
            fi
          else
            echo "**Location:** Failed to get address from GPS coordinates"
          fi
        else
          echo "**Location:** Unable to determine GPS coordinates"
        fi
        
        echo
        echo "**Network Speed:**"
        speedtest-cli --simple | sed 's/^/- /'
      '';
      description = "The speedtest script package";
    };
  };

  config = mkIf cfg.enable {
    # Append to home-manager packages for all users
    home-manager.sharedModules = [{
      home.packages = [ cfg.package pkgs.speedtest-cli ];
    }];

    # Append to existing Homebrew casks on Darwin
    homebrew.casks = mkIf pkgs.stdenv.isDarwin [ "corelocationcli" ];
  };
}