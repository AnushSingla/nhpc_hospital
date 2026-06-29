import pandas as pd
import requests
import time

# Replace with your actual API key
API_KEY = 'AIzaSyAm0zl3qVspZz0oWr_0W_YOnNg_0TvpQEM'

# Load your hospital CSV
df = pd.read_csv('Hospitals.csv')
df['Latitude'] = ''
df['Longitude'] = ''

# Loop through each hospital
for i, row in df.iterrows():
    query = f"{row['Hospital Name']}, {row['Address']}"
    url = f"https://maps.googleapis.com/maps/api/geocode/json?address={query}&key={API_KEY}"
    
    response = requests.get(url)
    data = response.json()
    
    if data['status'] == 'OK':
        location = data['results'][0]['geometry']['location']
        df.at[i, 'Latitude'] = location['lat']
        df.at[i, 'Longitude'] = location['lng']
        print(f"✓ Found: {row['Hospital Name']}")
    else:
        print(f"✗ Not found: {row['Hospital Name']}")

    time.sleep(0.2)  # Avoid rate limit (5 req/sec = safe)

# Save updated file
df.to_csv('Hospitals_with_coordinates.csv', index=False)
print("✅ All coordinates saved to 'Hospitals_with_coordinates.csv'")
