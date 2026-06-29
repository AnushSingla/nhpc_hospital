import re
import json
import mysql.connector
import time
import csv
import subprocess
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

class Config:
    def __init__(self, config_file='config.json'):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            print(f"✅ Loaded configuration from {config_file}")
        except FileNotFoundError:
            print(f"❌ Configuration file {config_file} not found!")
            raise
        except json.JSONDecodeError as e:
            print(f"❌ Error parsing configuration file: {e}")
            raise
    
    def get(self, section, key=None, fallback=None):
        """Get configuration value"""
        try:
            if key is None:
                return self.data.get(section, fallback)
            return self.data.get(section, {}).get(key, fallback)
        except (KeyError, AttributeError):
            if fallback is not None:
                return fallback
            raise KeyError(f"Configuration key '{section}.{key}' not found")
    
    def getint(self, section, key, fallback=None):
        """Get integer configuration value"""
        value = self.get(section, key, fallback)
        return int(value) if value is not None else fallback
    
    def getbool(self, section, key, fallback=None):
        """Get boolean configuration value"""
        value = self.get(section, key, fallback)
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            return value.lower() in ('true', 'yes', '1', 'on')
        return bool(value) if value is not None else fallback

config = Config()

# =============================================================================
# OLLAMA SLM INTEGRATION
# =============================================================================

class OllamaAddressSeparator:
    def __init__(self):
        self.model_name = config.get('ollama', 'model', 'gemma:2b')
        self.api_url = config.get('ollama', 'api_url', 'http://localhost:11434/api/generate')
        self.timeout = config.getint('ollama', 'timeout', 30)
        self.max_retries = config.getint('ollama', 'max_retries', 3)
        
    def check_ollama_service(self):
        """Check if Ollama service is running"""
        try:
            response = requests.get('http://localhost:11434/api/tags', timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def start_ollama_service(self):
        """Start Ollama service if not running"""
        if self.check_ollama_service():
            print("✅ Ollama service is already running")
            return True
        
        try:
            print("🚀 Starting Ollama service...")
            subprocess.Popen(['ollama', 'serve'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Wait for service to start
            for _ in range(10):
                time.sleep(2)
                if self.check_ollama_service():
                    print("✅ Ollama service started successfully")
                    return True
            
            print("❌ Failed to start Ollama service")
            return False
            
        except Exception as e:
            print(f"❌ Error starting Ollama service: {e}")
            return False
    
    def separate_address(self, address_text):
        """Separate bilingual address using Ollama SLM"""
        if not address_text or len(address_text.strip()) < 3:
            return "", ""
        
        # Ensure Ollama service is running
        if not self.check_ollama_service():
            if not self.start_ollama_service():
                print("⚠️ Ollama service unavailable, using fallback separation")
                return self._fallback_separation(address_text)
        
        prompt = f"""
You are an expert in separating bilingual Hindi-English addresses. 

Given this mixed Hindi-English address text, separate it into pure English and pure Hindi components.

Address: "{address_text}"

Rules:
1. Extract only English words/characters for English address
2. Extract only Hindi/Devanagari words/characters for Hindi address  
3. Keep numbers, punctuation, and PIN codes in both addresses
4. Remove serial numbers or list prefixes
5. Clean up extra spaces

Respond with ONLY a JSON object in this exact format:
{{"english_address": "clean English address here", "hindi_address": "clean Hindi address here"}}
"""

        payload = {
            "model": self.model_name,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.1,
                "top_p": 0.9,
                "num_predict": 200
            }
        }
        
        for attempt in range(self.max_retries):
            try:
                response = requests.post(
                    self.api_url, 
                    json=payload, 
                    timeout=self.timeout
                )
                
                if response.status_code == 200:
                    result = response.json()
                    response_text = result.get('response', '').strip()
                    
                    # Parse JSON response
                    json_response = self._extract_json(response_text)
                    if json_response:
                        english_addr = json_response.get('english_address', '').strip()
                        hindi_addr = json_response.get('hindi_address', '').strip()
                        
                        # Clean and validate results
                        english_addr = self._clean_address(english_addr)
                        hindi_addr = self._clean_address(hindi_addr)
                        
                        return english_addr, hindi_addr
                
            except Exception as e:
                print(f"⚠️ Ollama attempt {attempt + 1} failed: {e}")
                if attempt < self.max_retries - 1:
                    time.sleep(1)
        
        # Fallback if all attempts fail
        print(f"⚠️ Ollama separation failed for: {address_text[:50]}...")
        return self._fallback_separation(address_text)
    
    def _extract_json(self, text):
        """Extract JSON from LLM response"""
        try:
            # Find JSON-like content
            start = text.find('{')
            end = text.rfind('}') + 1
            
            if start != -1 and end > start:
                json_str = text[start:end]
                return json.loads(json_str)
        except:
            pass
        return None
    
    def _clean_address(self, address):
        """Basic address cleaning"""
        if not address:
            return ""
        
        # Remove extra whitespace
        address = re.sub(r'\s+', ' ', address)
        
        # Remove common artifacts
        address = re.sub(r'^[\d\.\s\-]+', '', address)  # Remove leading numbers
        address = re.sub(r'["\'\[\]{}]', '', address)    # Remove quotes/brackets
        
        return address.strip()
    
    def _fallback_separation(self, address_text):
        """Fallback method when Ollama is unavailable"""
        if not address_text:
            return "", ""
        
        # Simple regex-based separation
        hindi_pattern = re.compile(r'[\u0900-\u097F]+')
        english_pattern = re.compile(r'[A-Za-z]+')
        
        words = address_text.split()
        hindi_words = []
        english_words = []
        common_words = []
        
        for word in words:
            if hindi_pattern.search(word):
                hindi_words.append(word)
            elif english_pattern.search(word):
                english_words.append(word)
            elif re.match(r'[\d\-\.\,\/\(\)]+', word):
                # Numbers, PIN codes, punctuation - add to both
                common_words.append(word)
        
        english_result = ' '.join(english_words + common_words).strip()
        hindi_result = ' '.join(hindi_words + common_words).strip()
        
        return self._clean_address(english_result), self._clean_address(hindi_result)

# =============================================================================
# LOCATION MAPPING MANAGER
# =============================================================================

class LocationMapper:
    def __init__(self):
        """Initialize location mapper with data from CSV"""
        self.location_map = {}
        self.reverse_map = {}
        self.variations = {}
        self.load_location_mapping_from_csv()
        
    def load_location_mapping_from_csv(self):
        """Fixed location mapping loader that handles column name variations"""
        try:
            csv_file = config.get('files', 'location_csv')
            
            with open(csv_file, 'r', encoding='utf-8') as f:
                # Read first line to get column names
                header = f.readline().strip().split(',')
                f.seek(0)  # Reset to beginning of file
                
                # Find ID and name columns regardless of exact names
                id_col = None
                name_col = None
                
                for i, col in enumerate(header):
                    col_lower = col.lower()
                    if 'id' in col_lower or 'code' in col_lower:
                        id_col = i
                    elif 'name' in col_lower:
                        name_col = i
                
                if id_col is None or name_col is None:
                    raise ValueError(f"Could not identify ID and name columns in CSV. Header: {header}")
                
                # Read and process data
                reader = csv.reader(f)
                next(reader)  # Skip header
                
                for row in reader:
                    if len(row) > max(id_col, name_col):
                        loc_id = int(row[id_col])
                        loc_name = row[name_col].upper()
                        
                        self.location_map[loc_id] = loc_name
                        self.reverse_map[loc_name] = loc_id
    
        except Exception as e:
            print(f"❌ Error loading location mapping: {e}")
            # Initialize with fallback values
            self._initialize_fallback_mapping()
            
    def _initialize_fallback_mapping(self):
        """Initialize with hardcoded values as fallback"""
        state_map = {
            1: "DELHI", 2: "HARYANA", 3: "UTTAR PRADESH", 4: "UTTARAKHAND",
            5: "WEST BENGAL", 6: "BIHAR", 7: "MAHARASHTRA", 8: "PUNJAB",
            9: "HIMACHAL PRADESH", 10: "JAMMU AND KASHMIR", 11: "ODISHA",
            12: "JHARKHAND", 13: "ASSAM", 14: "MANIPUR", 15: "TAMIL NADU",
            16: "KARNATAKA", 17: "ANDHRA PRADESH", 18: "ARUNACHAL PRADESH",
            19: "CHHATTISGARH", 20: "GOA", 21: "GUJARAT", 22: "KERALA",
            23: "MADHYA PRADESH", 36: "TELANGANA"
        }
        
        # Create basic mappings
        self.location_map.update(state_map)
        for loc_id, loc_name in state_map.items():
            self.reverse_map[loc_name] = loc_id
        
        # State variations for better matching
        variations = {
            "DELHI": 1, "DL": 1, "NEW DELHI": 1, 
            "HARYANA": 2, "HR": 2,
            "UTTAR PRADESH": 3, "UP": 3, "U.P.": 3,
            "UTTARAKHAND": 4, "UK": 4, "UTTRAKHAND": 4,
            "WEST BENGAL": 5, "WB": 5, "BENGAL": 5,
            "BIHAR": 6, "BR": 6,
            "MAHARASHTRA": 7, "MH": 7, "MAHA": 7,
            "PUNJAB": 8, "PB": 8,
            "HIMACHAL PRADESH": 9, "HP": 9, "HIMACHAL": 9,
            "JAMMU AND KASHMIR": 10, "J&K": 10, "JAMMU": 10, "KASHMIR": 10, "UT OF JAMMU": 10,
            "ODISHA": 11, "ORISSA": 11,
            "JHARKHAND": 12, "JH": 12,
            "ASSAM": 13, "AS": 13,
            "MANIPUR": 14, "MN": 14,
            "TAMIL NADU": 15, "TN": 15, "TAMILNADU": 15,
            "KARNATAKA": 16, "KA": 16, "KAR": 16,
            "ANDHRA PRADESH": 17, "AP": 17, "ANDHRA": 17,
            "ARUNACHAL PRADESH": 18, "AR": 18, "ARUNACHAL": 18,
            "CHHATTISGARH": 19, "CG": 19, "CHATTISGARH": 19,
            "GOA": 20,
            "GUJARAT": 21, "GJ": 21, "GUJRAT": 21,
            "KERALA": 22, "KL": 22,
            "MADHYA PRADESH": 23, "MP": 23,
            "TELANGANA": 36, "TS": 36, "TG": 36
        }
        self.variations.update(variations)

# Global instances
location_mapper = LocationMapper()
address_separator = OllamaAddressSeparator()

# =============================================================================
# TEXT PROCESSOR
# =============================================================================

class TextProcessor:
    def __init__(self):
        # Compile regex patterns for name processing
        self.patterns = {
            'hindi_chars': re.compile(r'[\u0900-\u097F]'),
            'english_chars': re.compile(r'[A-Za-z]'),
            'whitespace': re.compile(r'\s+'),
            'separators': re.compile(r'[।|,]\s*'),
        }
    
    def clean_text(self, text):
        """Basic text cleaning"""
        if not text:
            return ""
        
        # Remove extra whitespace
        text = self.patterns['whitespace'].sub(' ', text)
        
        # Clean up common artifacts
        text = re.sub(r'[\u200b-\u200d\ufeff]', '', text)  # Zero-width characters
        text = re.sub(r'[\u201c\u201d\u2018\u2019\u201e\u201f\u201a\u2019\u201b]', '"', text)  # Normalize quotes
        
        return text.strip()
    
    def separate_hospital_names(self, text):
        """Separate hospital names - Hindi and English"""                                                                                                                                                                                                                                                                                                                                         
        if not text or len(text.strip()) < 2:
            return "", ""
        
        # Clean the text first
        text = self.clean_text(text)
        
        # Split into words and analyze each word
        words = text.split()
        hindi_words = []
        english_words = []
        
        for word in words:
            word = word.strip()
            if not word:
                continue
            
            # Check if word contains Hindi characters
            if self.patterns['hindi_chars'].search(word):
                hindi_words.append(word)
            elif self.patterns['english_chars'].search(word):
                english_words.append(word)
            elif word in ['&', '-', '(', ')', ',', '.', '/']:
                # Common punctuation/symbols - add to both if context suggests
                if hindi_words and not english_words:
                    hindi_words.append(word)
                elif english_words:
                    english_words.append(word)
                else:
                    # First occurrence - add to both
                    hindi_words.append(word)
                    english_words.append(word)
            else:
                # Numbers, special characters - usually part of English names
                english_words.append(word)
        
        # Join the words back
        hindi_name = ' '.join(hindi_words).strip()
        english_name = ' '.join(english_words).strip()
        
        # Final cleaning
        hindi_name = self.clean_text(hindi_name)
        english_name = self.clean_text(english_name)
        
        return english_name, hindi_name
    
    def separate_remarks_by_danda(self, text):
        """Separate Hindi and English remarks using Devanagari Danda (।)"""
        if not text or len(text.strip()) < 2:
            return "", ""
        
        # Clean the text first
        text = self.clean_text(text)
        
        # Primary method: Split by Devanagari Danda (।)
        if '।' in text:
            parts = text.split('।')
            
            if len(parts) == 2:
                # Standard pattern: "Hindi text । English text"
                hindi_part = parts[0].strip()
                english_part = parts[1].strip()
                
                # Clean any stray Hindi characters from English part
                english_part = re.sub(r'[\u0900-\u097F]+', ' ', english_part)
                english_part = self.patterns['whitespace'].sub(' ', english_part).strip()
                
                return english_part, hindi_part
            
            elif len(parts) > 2:
                # Multiple danda separators - group by language
                hindi_parts = []
                english_parts = []
                
                for part in parts:
                    part = part.strip()
                    if not part or len(part) < 2:
                        continue
                    
                    hindi_count = len(self.patterns['hindi_chars'].findall(part))
                    english_count = len(self.patterns['english_chars'].findall(part))
                    
                    if hindi_count > english_count:
                        hindi_parts.append(part)
                    else:
                        # Clean Hindi chars from English parts
                        clean_part = re.sub(r'[\u0900-\u097F]+', ' ', part)
                        clean_part = self.patterns['whitespace'].sub(' ', clean_part).strip()
                        if clean_part and len(clean_part) > 2:
                            english_parts.append(clean_part)
                
                return ' । '.join(english_parts), ' । '.join(hindi_parts)
        
        # Fallback: No danda separator found - word-by-word analysis
        return self._word_by_word_separation(text)
    
    def _word_by_word_separation(self, text):
        """Separate text word by word based on script"""
        words = text.split()
        hindi_words = []
        english_words = []
        
        for word in words:
            word = word.strip()
            if not word:
                continue
            
            # Check character composition
            hindi_chars = len(self.patterns['hindi_chars'].findall(word))
            english_chars = len(self.patterns['english_chars'].findall(word))
            
            if hindi_chars > 0 and hindi_chars >= english_chars:
                hindi_words.append(word)
            elif english_chars > 0:
                english_words.append(word)
            elif word.isdigit() or any(char in word for char in '.,/-()'):
                # Numbers and punctuation - context-sensitive
                if len(hindi_words) > len(english_words):
                    hindi_words.append(word)
                else:
                    english_words.append(word)
        
        english_result = ' '.join(english_words).strip()
        hindi_result = ' '.join(hindi_words).strip()
        
        return self.clean_text(english_result), self.clean_text(hindi_result)

# =============================================================================
# HOSPITAL EXTRACTOR WITH OLLAMA INTEGRATION
# =============================================================================

class HospitalExtractor:
    def __init__(self):
        self.text_processor = TextProcessor()
    
    def is_header_row(self, row):
        """Check if row is a header/separator row"""
        cells = row.find_all('td')
        
        # Check for colspan attribute (section headers often span multiple columns)
        if cells and len(cells) > 0:
            colspan = cells[0].get('colspan')
            if colspan and int(colspan) >= 3:
                text = cells[0].get_text(strip=True)
                return True, text
        
        # Handle single-cell headers (state names, scheme types)
        if len(cells) <= 1 and cells:
            cell = cells[0]
            text = cell.get_text(strip=True)
            
            # Check if it has state-like styling (typically bold or colored)
            has_state_styling = False
            
            # Check for bold text
            if cell.find('b') or cell.find('strong'):
                has_state_styling = True
                
            # Check for background color
            style = cell.get('style', '')
            if 'background' in style.lower() or 'bgcolor' in style.lower():
                has_state_styling = True
            
            # If we have a single cell with state-like styling, this is likely a state header
            if has_state_styling:
                return True, text
            
            # Still return as header if it's single cell
            return True, text
        
        # Check if first cell is not a number (could be a header)
        if cells:
            first_cell = cells[0].get_text(strip=True)
            if first_cell and not first_cell.isdigit():
                return True, first_cell
    
        return False, ""
    
    def is_state_header(self, text):
        """Check if header indicates a state and return the appropriate location code"""
        if not text:
            return False, None
        
        # Remove extra spaces and normalize
        text = text.upper().strip()
        
        # Method 1: Direct match with location map
        for state_name, loc_id in location_mapper.reverse_map.items():
            if state_name in text or text in state_name:
                return True, loc_id
        
        # Method 2: Check against variations map
        for state_name, loc_id in location_mapper.variations.items():
            if state_name in text or text in state_name:
                return True, loc_id
        
        # Method 3: Check for specific state keywords
        state_keywords = {
            "DELHI": 1, "HARYANA": 2, "UTTAR PRADESH": 3, "UP": 3,
            "UTTARAKHAND": 4, "WEST BENGAL": 5, "BENGAL": 5, "BIHAR": 6,
            "MAHARASHTRA": 7, "PUNJAB": 8, "HIMACHAL": 9, "HIMACHAL PRADESH": 9,
            "JAMMU": 10, "KASHMIR": 10, "J&K": 10, "UT OF JAMMU": 10,
            "ODISHA": 11, "ORISSA": 11, "JHARKHAND": 12, "ASSAM": 13, "MANIPUR": 14,
            "TAMIL NADU": 15, "TAMILNADU": 15, "KARNATAKA": 16, "ANDHRA": 17, 
            "ANDHRA PRADESH": 17, "ARUNACHAL": 18, "ARUNACHAL PRADESH": 18,
            "CHHATTISGARH": 19, "GOA": 20, "GUJARAT": 21, "GUJRAT": 21,
            "KERALA": 22, "MADHYA PRADESH": 23, "MP": 23, "TELANGANA": 36
        }
        
        for keyword, loc_id in state_keywords.items():
            if keyword in text:
                return True, loc_id
        
        return False, None
    
    def is_scheme_header(self, row_element, header_text):
        """Check if header indicates payment scheme type"""
        if not header_text:
            return False, None
            
        header_text = header_text.upper().strip()
        
        # Check for colspan attribute (scheme headers typically span all columns)
        colspan = row_element.find('td').get('colspan')
        if colspan and int(colspan) >= 10:
            # Check for Direct Payment indicators
            if "DIRECT PAYMENT" in header_text and "WITHOUT" not in header_text:
                return True, 'D'
            
            # Check for Without Direct Payment indicators
            if "WITHOUT DIRECT PAYMENT" in header_text:
                return True, 'I'
            
            # Check for color in HTML (blue = Direct, red = Without Direct)
            td = row_element.find('td')
            style = td.get('style', '')
            font_tag = td.find('font')
            
            # Check for blue color (Direct Payment)
            if 'blue' in style.lower() or (font_tag and 'blue' in font_tag.get('color', '').lower()):
                return True, 'D'
                
            # Check for red color (Without Direct Payment)
            if 'red' in style.lower() or (font_tag and 'red' in font_tag.get('color', '').lower()):
                return True, 'I'
        
        # Check text content for scheme indicators
        if "DIRECT PAYMENT SCHEME" in header_text and "WITHOUT" not in header_text:
            return True, 'D'
        
        if "WITHOUT DIRECT PAYMENT" in header_text:
            return True, 'I'
        
        return False, None
    
    def clean_date(self, date_str):
        """Clean and standardize date format"""
        if not date_str:
            return None
        
        # Remove extra whitespace and common artifacts
        date_str = re.sub(r'\s+', ' ', date_str.strip())
        
        # Try different date formats
        date_formats = [
            '%d.%m.%Y', '%d/%m/%Y', '%d-%m-%Y',
            '%d.%m.%y', '%d/%m/%y', '%d-%m-%y'
        ]
        
        for fmt in date_formats:
            try:
                parsed_date = datetime.strptime(date_str, fmt)
                return parsed_date.strftime('%Y-%m-%d')
            except ValueError:
                continue
        
        return None
    
    def extract_hospitals_from_html(self, html_file):
        """Main extraction logic with Ollama address processing"""
        try:
            with open(html_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            soup = BeautifulSoup(content, "html.parser")
            
            # Find the main data table
            table = soup.find('table', {'id': 'table1'})
            if not table:
                tables = soup.find_all('table')
                if tables:
                    table = max(tables, key=lambda t: len(t.find_all('tr')))
                else:
                    print("❌ No data table found in HTML file")
                    return []
            
            rows = table.find_all('tr')
            hospitals = []
            current_loc_code = 1  # Default to Delhi
            current_scheme = 'D'  # Default to Direct Payment
            
            print(f"📊 Processing {len(rows)} rows...")
            start_time = time.time()
            
            for row_num, row in enumerate(rows):
                # Check for header rows
                is_header, header_text = self.is_header_row(row)
                if is_header:
                    # Check if it's a state header
                    is_state, loc_code = self.is_state_header(header_text)
                    if is_state and loc_code is not None:
                        current_loc_code = loc_code
                    
                    # Check if it's a scheme header
                    is_scheme, scheme_type = self.is_scheme_header(row, header_text)
                    if is_scheme:
                        current_scheme = scheme_type
                    
                    continue
                
                # Process data rows
                cells = row.find_all('td')
                if len(cells) < 3:
                    continue
                
                # Extract basic data
                serial_col = cells[0].get_text(strip=True)
                name_col = cells[1].get_text(strip=True) if len(cells) > 1 else ""
                address_col = cells[2].get_text(strip=True) if len(cells) > 2 else ""
                
                # Skip invalid rows
                if not serial_col.isdigit() or len(name_col.strip()) < config.getint('thresholds', 'min_name_length', 3):
                    continue
                
                # Extract additional columns
                valid_from_col = cells[3].get_text(strip=True) if len(cells) > 3 else ""
                valid_upto_col = cells[4].get_text(strip=True) if len(cells) > 4 else ""
                reg_valid_upto_col = cells[5].get_text(strip=True) if len(cells) > 5 else ""
                remarks_col = cells[6].get_text(strip=True) if len(cells) > 6 else ""
                
                # Process name separation
                eng_name, hindi_name = self.text_processor.separate_hospital_names(name_col)
                
                # Process address using Ollama SLM
                print(f"🔄 Processing address {row_num}: {address_col[:50]}...")
                eng_address, hindi_address = address_separator.separate_address(address_col)
                
                # Process remarks
                eng_remarks, hindi_remarks = self.text_processor.separate_remarks_by_danda(remarks_col)
                
                # Clean and validate
                eng_name = self.text_processor.clean_text(eng_name)
                if not eng_name or len(eng_name) < config.getint('thresholds', 'min_name_length', 3):
                    continue
                
                # Process dates
                valid_from = self.clean_date(valid_from_col)
                valid_upto = self.clean_date(valid_upto_col)
                reg_valid_upto = self.clean_date(reg_valid_upto_col)
                
                # Make sure loc_code is always an integer
                if current_loc_code is None:
                    current_loc_code = 1
                
                # Create hospital record with separated addresses
                hospital = {
                    "hosp_name": eng_name,
                    "hosp_name_h": hindi_name,
                    "english_address": eng_address,  # SLM separated English address
                    "hindi_address": hindi_address,   # SLM separated Hindi address
                    "valid_from": valid_from,
                    "valid_upto": valid_upto,
                    "reg_valid_upto": reg_valid_upto,
                    "english_remarks": eng_remarks,
                    "hindi_remarks": hindi_remarks,
                    "loc_code": int(current_loc_code),
                    "scheme": current_scheme
                }
                
                hospitals.append(hospital)
                
                # Add small delay to prevent overwhelming Ollama
                time.sleep(0.1)
            
            processing_time = time.time() - start_time
            print(f"⏱️ Extraction completed in {processing_time:.2f} seconds")
            print(f"📊 Total hospitals extracted: {len(hospitals)}")
            
            return hospitals
                
        except Exception as e:
            print(f"❌ Error extracting hospitals: {e}")
            import traceback
            traceback.print_exc()
            return []

# =============================================================================
# DATABASE MANAGER
# =============================================================================

class DatabaseManager:
    def __init__(self):
        self.connection = None
        self.cursor = None
    
    def connect(self):
        """Connect to database"""
        try:
            self.connection = mysql.connector.connect(
                host=config.get('database', 'host'),
                user=config.get('database', 'user'),
                password=config.get('database', 'password'),
                database=config.get('database', 'database'),
                port=config.getint('database', 'port', 3306),
                charset='utf8mb4',
                collation='utf8mb4_unicode_ci',
                autocommit=False
            )
            self.cursor = self.connection.cursor()
            print("✅ Database connected successfully")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def backup_table(self):
        """Create a backup of existing data before truncating"""
        try:
            backup_table_name = f"hospitals_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            # Create backup table
            backup_query = f"""
            CREATE TABLE {backup_table_name} AS 
            SELECT * FROM hospitals
            """
            
            self.cursor.execute(backup_query)
            self.connection.commit()
            print(f"✅ Backup created: {backup_table_name}")
            
            # Get record count
            self.cursor.execute(f"SELECT COUNT(*) FROM {backup_table_name}")
            count = self.cursor.fetchone()[0]
            print(f"📊 Backed up {count} records")
            
            return backup_table_name
            
        except Exception as e:
            print(f"⚠️ Backup failed (continuing anyway): {e}")
            return None
    
    def cleanup_old_backups(self, keep_days=7):
        """Remove backup tables older than specified days"""
        try:
            # Get all backup tables
            self.cursor.execute("SHOW TABLES LIKE 'hospitals_backup_%'")
            backup_tables = [table[0] for table in self.cursor.fetchall()]
            
            cutoff_date = datetime.now() - timedelta(days=keep_days)
            
            for table_name in backup_tables:
                # Extract date from table name
                try:
                    date_part = table_name.replace('hospitals_backup_', '').split('_')[0]
                    table_date = datetime.strptime(date_part, '%Y%m%d')
                    
                    if table_date < cutoff_date:
                        self.cursor.execute(f"DROP TABLE {table_name}")
                        print(f"🗑️ Removed old backup: {table_name}")
                        
                except (ValueError, IndexError):
                    # Skip tables with invalid date format
                    continue
            
            self.connection.commit()
            
        except Exception as e:
            print(f"⚠️ Backup cleanup failed: {e}")
    
    def truncate_table(self):
        """Truncate the hospitals table"""
        try:
            # Disable foreign key checks temporarily
            self.cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
            
            # Truncate the table
            self.cursor.execute("TRUNCATE TABLE hospitals")
            
            # Re-enable foreign key checks
            self.cursor.execute("SET FOREIGN_KEY_CHECKS = 1")
            
            self.connection.commit()
            print("🗑️ Hospital table truncated successfully")
            
        except Exception as e:
            print(f"❌ Error truncating table: {e}")
            self.connection.rollback()
            raise
    
    def get_table_stats(self):
        """Get statistics about the current table"""
        try:
            self.cursor.execute("SELECT COUNT(*) FROM hospitals")
            total_count = self.cursor.fetchone()[0]
            
            self.cursor.execute("SELECT COUNT(DISTINCT LOC_CODE) FROM hospitals")
            unique_locations = self.cursor.fetchone()[0]
            
            self.cursor.execute("SELECT COUNT(*) FROM hospitals WHERE SCHEME = 'D'")
            direct_payment = self.cursor.fetchone()[0]
            
            self.cursor.execute("SELECT COUNT(*) FROM hospitals WHERE SCHEME = 'I'")
            indirect_payment = self.cursor.fetchone()[0]
            
            return {
                'total_hospitals': total_count,
                'unique_locations': unique_locations,
                'direct_payment': direct_payment,
                'indirect_payment': indirect_payment
            }
            
        except Exception as e:
            print(f"⚠️ Error getting table stats: {e}")
            return None
    
    def insert_hospitals(self, hospitals):
        """Insert hospitals with separated addresses"""
        if not hospitals:
            print("⚠️ No hospitals to insert")
            return 0
        
        insert_query = """
        INSERT INTO hospitals (
            Hosp_name, Hosp_name_H, hosp_add, hosp_add_H,
            valid_from, VALID_UPTO, RegValidUptoDt,
            Rem, Rem_h, LOC_CODE, SCHEME
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        )
        """
        
        try:
            batch_size = config.getint('performance', 'batch_size', 100)
            total_inserted = 0
            
            for i in range(0, len(hospitals), batch_size):
                batch = hospitals[i:i + batch_size]
                batch_data = []
                
                for hospital in batch:
                    # Ensure loc_code is valid
                    loc_code = hospital.get('loc_code', 1)
                    try:
                        loc_code = int(loc_code)
                    except (TypeError, ValueError):
                        loc_code = 1
                    
                    batch_data.append((
                        hospital.get('hosp_name', ''),         # Hosp_name
                        hospital.get('hosp_name_h', ''),       # Hosp_name_H
                        hospital.get('english_address', ''),   # hosp_add (English)
                        hospital.get('hindi_address', ''),     # hosp_add_H (Hindi)
                        hospital.get('valid_from'),            # valid_from
                        hospital.get('valid_upto'),            # VALID_UPTO
                        hospital.get('reg_valid_upto'),        # RegValidUptoDt
                        hospital.get('english_remarks', ''),   # Rem
                        hospital.get('hindi_remarks', ''),     # Rem_h
                        loc_code,                              # LOC_CODE
                        hospital.get('scheme', 'D')            # SCHEME
                    ))
                
                self.cursor.executemany(insert_query, batch_data)
                self.connection.commit()
                total_inserted += len(batch)
                
                print(f"📈 Inserted batch {i//batch_size + 1}: {total_inserted} total records")
            
            return total_inserted
            
        except Exception as e:
            print(f"❌ Error inserting hospitals: {e}")
            self.connection.rollback()
            raise
    
    def close(self):
        """Close database connection"""
        try:
            if self.cursor:
                self.cursor.close()
            if self.connection:
                self.connection.close()
            print("🔒 Database connection closed")
        except Exception as e:
            print(f"⚠️ Error closing database: {e}")

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __name__ == "__main__":
    try:
        print("🚀 Starting NHPC Hospital Data Extraction with Ollama SLM")
        
        # Initialize components
        extractor = HospitalExtractor()
        db_manager = DatabaseManager()
        
        # Check Ollama availability
        if not address_separator.check_ollama_service():
            print("⚠️ Ollama service not detected. Attempting to start...")
            address_separator.start_ollama_service()
        
        # Connect to database
        if not db_manager.connect():
            print("❌ Failed to connect to database. Exiting.")
            exit(1)
        
        #db_manager.create_table()
        
        # Extract hospitals
        html_file = config.get('files', 'html_file')
        print(f"🔍 Extracting hospitals from: {html_file}")
        
        hospitals = extractor.extract_hospitals_from_html(html_file)
        
        if not hospitals:
            print("❌ No hospitals extracted!")
            db_manager.close()
            exit(1)
        
        print(f"✅ Extracted {len(hospitals)} hospitals")
        
        # Upload to database
        success_count = db_manager.insert_hospitals(hospitals)
        print(f"✅ Successfully inserted {success_count} hospitals into database")
        
        db_manager.close()
        print("🎉 Process completed successfully!")
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        
        # Ensure database connection is closed
        try:
            db_manager.close()
        except:
            pass