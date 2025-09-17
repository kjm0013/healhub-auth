#!/usr/bin/env python3
"""
Reddit Home Remedy Scraper
Fetches and processes home remedy posts from Reddit for HealHub app
"""

import json
import re
import time
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import requests
from urllib.parse import urlparse

class RedditRemedyScraper:
    def __init__(self):
        self.subreddits = [
            "https://www.reddit.com/r/NaturalRemedies",
            "https://www.reddit.com/r/herbalism", 
            "https://www.reddit.com/r/AlternativeHealth",
            "https://www.reddit.com/r/Ayurveda",
            "https://www.reddit.com/r/essentialoils"
        ]
        self.headers = {
            'User-Agent': 'HealthHub Natural Remedy Collector 1.0'
        }
        self.remedies = []
        self.symptom_keywords = {
            # Respiratory
            'cold': ['cold', 'runny nose', 'sneezing', 'nasal'],
            'flu': ['flu', 'influenza', 'fever', 'body ache'],
            'cough': ['cough', 'coughing', 'throat tickle'],
            'sore throat': ['sore throat', 'throat pain', 'strep'],
            'congestion': ['congestion', 'stuffy nose', 'blocked nose', 'sinus'],
            
            # Pain
            'headache': ['headache', 'migraine', 'head pain'],
            'back pain': ['back pain', 'backache', 'spine'],
            'joint pain': ['joint pain', 'arthritis', 'knee pain', 'joint ache'],
            'muscle pain': ['muscle pain', 'sore muscles', 'muscle ache'],
            
            # Digestive
            'stomach ache': ['stomach', 'belly', 'abdominal pain', 'tummy'],
            'nausea': ['nausea', 'queasy', 'sick stomach'],
            'constipation': ['constipation', 'constipated', 'bowel'],
            'diarrhea': ['diarrhea', 'loose stool', 'upset stomach'],
            'acid reflux': ['acid reflux', 'heartburn', 'gerd', 'indigestion'],
            
            # Skin
            'acne': ['acne', 'pimple', 'breakout', 'zit'],
            'eczema': ['eczema', 'dermatitis', 'itchy skin'],
            'sunburn': ['sunburn', 'sun damage', 'burned skin'],
            'rash': ['rash', 'hives', 'skin irritation'],
            
            # Other
            'insomnia': ['insomnia', 'cant sleep', 'sleep problem', 'sleepless'],
            'stress': ['stress', 'anxiety', 'tension', 'worried'],
            'fatigue': ['fatigue', 'tired', 'exhausted', 'low energy'],
            'allergies': ['allergy', 'allergies', 'allergic', 'hay fever']
        }

    def extract_symptom(self, title: str, selftext: str) -> str:
        """Extract the primary symptom from post title and content"""
        combined_text = f"{title} {selftext}".lower()
        
        # Check for exact matches first
        for symptom, keywords in self.symptom_keywords.items():
            for keyword in keywords:
                if keyword in combined_text:
                    return symptom
        
        # If no match, try to extract from common patterns
        patterns = [
            r'for\s+(\w+(?:\s+\w+)?)',
            r'cure\s+(\w+(?:\s+\w+)?)',
            r'treat\s+(\w+(?:\s+\w+)?)',
            r'help\s+with\s+(\w+(?:\s+\w+)?)',
            r'remedy\s+for\s+(\w+(?:\s+\w+)?)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, title.lower())
            if match:
                potential_symptom = match.group(1).strip()
                # Check if it matches any known symptom
                for symptom in self.symptom_keywords:
                    if potential_symptom in symptom or symptom in potential_symptom:
                        return symptom
                return potential_symptom
        
        return "general wellness"

    def extract_remedy_name(self, title: str, selftext: str) -> str:
        """Extract the remedy name from post"""
        # Common remedy patterns
        remedy_patterns = [
            r'use\s+(\w+(?:\s+\w+)?)',
            r'try\s+(\w+(?:\s+\w+)?)',
            r'(\w+(?:\s+\w+)?)\s+works',
            r'(\w+(?:\s+\w+)?)\s+helps',
            r'(\w+(?:\s+oil)?)\s+for'
        ]
        
        for pattern in remedy_patterns:
            match = re.search(pattern, title.lower())
            if match:
                remedy = match.group(1).strip()
                # Filter out common words
                if remedy not in ['this', 'that', 'it', 'the', 'a', 'an']:
                    return remedy
        
        # Try to extract from title
        # Remove common words and extract key terms
        words = title.lower().split()
        ignore_words = {'for', 'the', 'a', 'an', 'to', 'with', 'help', 'cure', 'treat', 'remedy', 'home', 'natural'}
        remedy_words = [w for w in words if w not in ignore_words and len(w) > 2]
        
        if remedy_words:
            return ' '.join(remedy_words[:3])  # Take first 3 meaningful words
        
        return "natural remedy"

    def clean_description(self, text: str) -> str:
        """Clean and format description text"""
        # Remove URLs
        text = re.sub(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', '', text)
        
        # Remove multiple spaces and newlines
        text = ' '.join(text.split())
        
        # Limit length
        if len(text) > 500:
            text = text[:497] + "..."
        
        # Ensure it ends with proper punctuation
        if text and text[-1] not in '.!?':
            text += '.'
        
        return text.strip()

    def fetch_posts(self, limit=100, time_filter='all') -> List[Dict]:
        """Fetch posts from multiple subreddits"""
        all_posts = []
        
        for subreddit_url in self.subreddits:
            posts = []
            after = None
            posts_per_sub = limit // len(self.subreddits)
            
            while len(posts) < posts_per_sub:
                url = f"{subreddit_url}/top.json"
                params = {
                    't': time_filter,
                    'limit': min(25, posts_per_sub - len(posts))
                }
                if after:
                    params['after'] = after
                
                try:
                    response = requests.get(url, headers=self.headers, params=params, timeout=10)
                    response.raise_for_status()
                    
                    data = response.json()
                    children = data.get('data', {}).get('children', [])
                    
                    if not children:
                        break
                    
                    posts.extend(children)
                    after = data.get('data', {}).get('after')
                    
                    if not after:
                        break
                    
                    # Rate limiting
                    time.sleep(2)
                    
                except requests.RequestException as e:
                    print(f"Error fetching from {subreddit_url}: {e}")
                    break
            
            all_posts.extend(posts)
            print(f"Fetched {len(posts)} posts from {subreddit_url}")
        
        return all_posts

    def process_post(self, post: Dict, index: int) -> Optional[Dict]:
        """Process a single Reddit post into remedy format"""
        try:
            data = post.get('data', {})
            
            # Skip if deleted or removed
            if data.get('selftext') in ['[deleted]', '[removed]', None, '']:
                return None
            
            title = data.get('title', '')
            selftext = data.get('selftext', '')
            score = data.get('score', 0)
            
            # Skip low-quality posts
            if score < 2 or len(selftext) < 20:
                return None
            
            # Skip inappropriate content
            inappropriate_words = ['anal', 'fissure', 'sex', 'porn', 'genital']
            combined_text = (title + " " + selftext).lower()
            if any(word in combined_text for word in inappropriate_words):
                return None
            
            symptom = self.extract_symptom(title, selftext)
            remedy_name = self.extract_remedy_name(title, selftext)
            description = self.clean_description(selftext)
            
            # Create structured remedy
            remedy = {
                "id": index + 1,
                "symptom": symptom,
                "title": remedy_name,
                "description": description,
                "videoURL": f"remedy_{index + 1}.mp4",  # Placeholder for your videos
                "source": "reddit",
                "upvotes": score,
                "dateAdded": datetime.now().isoformat(),
                "approved": True,  # Pre-approved since you're curating
                "featured": score > 50  # Feature high-scoring remedies
            }
            
            return remedy
            
        except Exception as e:
            print(f"Error processing post: {e}")
            return None

    def deduplicate_remedies(self, remedies: List[Dict]) -> List[Dict]:
        """Remove duplicate remedies based on symptom and title similarity"""
        unique_remedies = []
        seen = set()
        
        for remedy in remedies:
            # Create a key based on symptom and first word of title
            key = f"{remedy['symptom']}_{remedy['title'].split()[0].lower()}"
            
            if key not in seen:
                seen.add(key)
                unique_remedies.append(remedy)
        
        return unique_remedies

    def scrape_remedies(self, target_count=100):
        """Main scraping function"""
        print("Starting Reddit scraping...")
        
        # Fetch more posts than needed to account for filtering
        posts = self.fetch_posts(limit=target_count * 3)
        print(f"Fetched {len(posts)} posts from Reddit")
        
        # Process posts
        valid_remedies = []
        for i, post in enumerate(posts):
            remedy = self.process_post(post, len(valid_remedies))
            if remedy:
                valid_remedies.append(remedy)
                print(f"Processed remedy {len(valid_remedies)}: {remedy['title']} for {remedy['symptom']}")
            
            if len(valid_remedies) >= target_count:
                break
        
        # Sort by upvotes and deduplicate
        valid_remedies.sort(key=lambda x: x['upvotes'], reverse=True)
        self.remedies = self.deduplicate_remedies(valid_remedies)[:target_count]
        
        print(f"\nScraped {len(self.remedies)} unique remedies")
        
        # Print symptom distribution
        symptom_counts = {}
        for remedy in self.remedies:
            symptom = remedy['symptom']
            symptom_counts[symptom] = symptom_counts.get(symptom, 0) + 1
        
        print("\nSymptom distribution:")
        for symptom, count in sorted(symptom_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"  {symptom}: {count} remedies")

    def save_to_json(self, filename="remedies_data.json"):
        """Save remedies to JSON file"""
        output = {
            "remedies": self.remedies,
            "metadata": {
                "version": "1.0",
                "lastUpdated": datetime.now().isoformat(),
                "totalRemedies": len(self.remedies),
                "source": "Reddit r/Home_Remedy"
            }
        }
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        
        print(f"\nSaved {len(self.remedies)} remedies to {filename}")

    def save_for_cloudkit(self, filename="remedies_cloudkit.json"):
        """Save remedies in CloudKit-ready format"""
        # CloudKit prefers flat structure with typed fields
        cloudkit_records = []
        
        for remedy in self.remedies:
            record = {
                "recordType": "Remedy",
                "fields": {
                    "remedyID": {"value": remedy["id"]},
                    "symptom": {"value": remedy["symptom"]},
                    "title": {"value": remedy["title"]},
                    "description": {"value": remedy["description"]},
                    "videoURL": {"value": remedy["videoURL"]},
                    "upvotes": {"value": remedy["upvotes"]},
                    "featured": {"value": remedy["featured"]},
                    "approved": {"value": remedy["approved"]},
                    "dateAdded": {"value": remedy["dateAdded"]},
                    "source": {"value": remedy["source"]}
                }
            }
            cloudkit_records.append(record)
        
        output = {
            "records": cloudkit_records,
            "metadata": {
                "containerID": "iCloud.com.yourcompany.HealHub",
                "environment": "production"
            }
        }
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(output, f, indent=2)
        
        print(f"Saved CloudKit-ready data to {filename}")

    def create_sample_videos_list(self, filename="videos_to_create.txt"):
        """Create a list of videos that need to be created"""
        with open(filename, 'w') as f:
            f.write("Videos to Create for HealHub\n")
            f.write("=" * 50 + "\n\n")
            
            for remedy in self.remedies:
                f.write(f"Video ID: {remedy['videoURL']}\n")
                f.write(f"Symptom: {remedy['symptom']}\n")
                f.write(f"Remedy: {remedy['title']}\n")
                f.write(f"Description: {remedy['description'][:100]}...\n")
                f.write("-" * 30 + "\n\n")
        
        print(f"Created video list in {filename}")


def main():
    scraper = RedditRemedyScraper()
    
    # Scrape remedies
    scraper.scrape_remedies(target_count=50)  # Start with 50, can increase
    
    # Save in multiple formats
    scraper.save_to_json()
    scraper.save_for_cloudkit()
    scraper.create_sample_videos_list()
    
    print("\nScraping complete! Next steps:")
    print("1. Review remedies_data.json for content quality")
    print("2. Create videos based on videos_to_create.txt")
    print("3. Import remedies_cloudkit.json to CloudKit")


if __name__ == "__main__":
    main()