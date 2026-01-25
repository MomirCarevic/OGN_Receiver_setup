#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OGN Configuration File Generator ===${NC}\n"

# Check if Template.conf exists
if [ ! -f "Template.conf" ]; then
    echo -e "${RED}Error: Template.conf not found in current directory${NC}"
    exit 1
fi

# Prompt for new filename
read -p "Enter name for new config file (e.g., MyStation.conf): " new_filename

# Add .conf extension if not provided
if [[ ! "$new_filename" == *.conf ]]; then
    new_filename="${new_filename}.conf"
fi

# Check if file already exists
if [ -f "$new_filename" ]; then
    read -p "File $new_filename already exists. Overwrite? (y/n): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo -e "\n${GREEN}Please enter configuration values:${NC}\n"

# RF Section
echo "--- RF Configuration ---"
read -p "Frequency Correction [ppm] (default: +50): " freq_corr
freq_corr=${freq_corr:-+50}

read -p "Sample Rate [MHz] (1.0 or 2.0, default: 2.0): " sample_rate
sample_rate=${sample_rate:-2.0}

# GSM Section
echo -e "\n--- GSM Configuration (for frequency calibration) ---"
read -p "GSM Center Frequency [MHz] (default: 938.4): " gsm_freq
gsm_freq=${gsm_freq:-938.4}

read -p "GSM Gain [dB] (default: 25.0): " gsm_gain
gsm_gain=${gsm_gain:-25.0}

# OGN Section
echo -e "\n--- OGN Configuration ---"
read -p "OGN Center Frequency [MHz] (default: 868.8): " ogn_freq
ogn_freq=${ogn_freq:-868.8}

read -p "OGN Gain [dB] (default: 50.0): " ogn_gain
ogn_gain=${ogn_gain:-50.0}

# Position Section
echo -e "\n--- Antenna Position ---"
read -p "Latitude [deg] (e.g., +48.0000): " latitude
while [[ -z "$latitude" ]]; do
    echo -e "${RED}Latitude is required!${NC}"
    read -p "Latitude [deg] (e.g., +48.0000): " latitude
done

read -p "Longitude [deg] (e.g., +9.0000): " longitude
while [[ -z "$longitude" ]]; do
    echo -e "${RED}Longitude is required!${NC}"
    read -p "Longitude [deg] (e.g., +9.0000): " longitude
done

read -p "Altitude AMSL [m] (default: 100): " altitude
altitude=${altitude:-100}

# APRS Section
echo -e "\n--- APRS Configuration ---"
read -p "APRS Callsign (max 9 chars, leave empty to keep commented): " aprs_call

# Copy template and replace values
cp Template.conf "$new_filename"

# Use sed to replace values
sed -i "s/FreqCorr = +50;/FreqCorr = $freq_corr;/" "$new_filename"
sed -i "s/SampleRate = 2.0;/SampleRate = $sample_rate;/" "$new_filename"
sed -i "s/CenterFreq  = 938.4;/CenterFreq  = $gsm_freq;/" "$new_filename"
sed -i "s/Gain        =  25.0;/Gain        =  $gsm_gain;/" "$new_filename"
sed -i "s/CenterFreq = 868.8;/CenterFreq = $ogn_freq;/" "$new_filename"
sed -i "s/Gain       =  50.0;/Gain       =  $ogn_gain;/" "$new_filename"
sed -i "s/Latitude   =   +48.0000;/Latitude   =   $latitude;/" "$new_filename"
sed -i "s/Longitude  =    +9.0000;/Longitude  =    $longitude;/" "$new_filename"
sed -i "s/Altitude   =        100;/Altitude   =        $altitude;/" "$new_filename"

# Handle APRS callsign (uncomment line if provided)
if [[ -n "$aprs_call" ]]; then
    sed -i "s/# Call = \"NewOGNrx\";/Call = \"$aprs_call\";/" "$new_filename"
fi

echo -e "\n${GREEN}✓ Configuration file created: $new_filename${NC}"
echo -e "Review the file and make any additional adjustments as needed.\n"

# Export the filename so it can be used by the calling script
export OGN_CONFIG_FILE="$new_filename"