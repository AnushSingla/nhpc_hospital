import pandas as pd
import requests
import time

# STEP 1: File paths
INPUT_FILE = "Hospitals_with_coordinates.csv"
OUTPUT_FILE = "Hospitals_with_verified_addresses.csv"

# STEP 2: Insert your Google Maps API key
API_KEY = "AIzaSyAm0zl3qVspZz0oWr_0W_YOnNg_0TvpQEM"  # <-- Replace this with your actual API key

# STEP 3: Load the input CSV
try:
    df = pd.read_csv(INPUT_FILE)
except FileNotFoundError:
    print(f"❌ File '{INPUT_FILE}' not found. Please check the file name and location.")
    exit()

# STEP 4: Define the reverse geocoding function
def reverse_geocode(lat, lng):
    url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {
        "latlng": f"{lat},{lng}",
        "key": API_KEY
    }
    response = requests.get(url, params=params)
    if response.status_code == 200:
        data = response.json()
        if data['status'] == 'OK':
            return data['results'][0]['formatted_address']
        else:
            return f"Error: {data['status']}"
    else:
        return f"HTTP Error: {response.status_code}"

# STEP 5: Reverse geocode all rows
verified_addresses = []

print("🔄 Verifying coordinates...")
for index, row in df.iterrows():
    name = row.get('Hospital Name', f"Hospital {index+1}")
    lat = row.get('Latitude')
    lng = row.get('Longitude')

    if pd.notna(lat) and pd.notna(lng):
        address = reverse_geocode(lat, lng)
        print(f"{index+1}. {name} → {address}")
    else:
        address = "Missing coordinates"

    verified_addresses.append(address)
    time.sleep(0.25)  # Stay under free-tier rate limits

# STEP 6: Add results and save to new CSV
df['Verified Address'] = verified_addresses
df.to_csv(OUTPUT_FILE, index=False)

print(f"\n✅ Done! Saved to: {OUTPUT_FILE}")
