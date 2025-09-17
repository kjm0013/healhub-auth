import json
import re
from collections import Counter, defaultdict

def analyze_reddit_remedies(json_file):
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    posts = data['data']['children']
    
    symptoms = []
    remedies = []
    video_count = 0
    text_count = 0
    total_upvotes = 0
    total_comments = 0
    
    symptom_keywords = [
        'headache', 'sore throat', 'joint pain', 'acid reflux', 'eye strain',
        'congestion', 'sunburn', 'anxiety', 'insect bite', 'mosquito bite',
        'puffy eyes', 'back pain', 'oral health', 'eczema', 'uti', 'cold',
        'flu', 'hemorrhoids', 'nausea', 'muscle soreness', 'immune system',
        'tension', 'inflamed skin', 'itchy skin', 'gum', 'teeth'
    ]
    
    remedy_keywords = [
        'peppermint oil', 'ginger tea', 'honey', 'lemon', 'turmeric',
        'coconut oil', 'apple cider vinegar', 'chamomile', 'eucalyptus',
        'aloe vera', 'salt water', 'lavender oil', 'baking soda',
        'green tea', 'yoga', 'oil pulling', 'oatmeal', 'cranberry juice',
        'elderberry', 'witch hazel', 'acupressure', 'epsom salt', 'garlic',
        'black pepper', 'vinegar', 'compress', 'steam', 'diffuser'
    ]
    
    for post in posts:
        post_data = post['data']
        title = post_data.get('title', '').lower()
        text = post_data.get('selftext', '').lower()
        content = title + ' ' + text
        
        for symptom in symptom_keywords:
            if symptom in content:
                symptoms.append(symptom)
        
        for remedy in remedy_keywords:
            if remedy in content:
                remedies.append(remedy)
        
        if 'url' in post_data and any(vid in post_data['url'] for vid in ['youtube', 'vimeo', 'video']):
            video_count += 1
        elif post_data.get('selftext', '').strip():
            text_count += 1
        
        total_upvotes += post_data.get('ups', 0)
        total_comments += post_data.get('num_comments', 0)
    
    total_posts = len(posts)
    
    symptom_counts = Counter(symptoms)
    remedy_counts = Counter(remedies)
    
    top_symptoms = [item[0] for item in symptom_counts.most_common(10)]
    top_remedies = [item[0] for item in remedy_counts.most_common(10)]
    
    video_percentage = (video_count / total_posts) * 100 if total_posts > 0 else 0
    text_percentage = (text_count / total_posts) * 100 if total_posts > 0 else 0
    other_percentage = 100 - video_percentage - text_percentage
    
    avg_upvotes = total_upvotes / total_posts if total_posts > 0 else 0
    avg_comments = total_comments / total_posts if total_posts > 0 else 0
    
    suggested_features = [
        "Symptom-based search with auto-complete",
        "Video tutorial integration with bookmarking",
        "User rating system for remedy effectiveness",
        "Personalized remedy tracker with reminders",
        "AI-powered remedy recommendation based on symptoms"
    ]
    
    result = {
        "top_symptoms": top_symptoms[:10],
        "top_remedies": top_remedies[:10],
        "content_types": {
            "videos": f"{video_percentage:.1f}%",
            "text": f"{text_percentage:.1f}%",
            "other": f"{other_percentage:.1f}%"
        },
        "engagement": {
            "avg_upvotes": round(avg_upvotes),
            "avg_comments": round(avg_comments)
        },
        "suggested_features": suggested_features,
        "analysis_summary": {
            "total_posts_analyzed": total_posts,
            "unique_symptoms_found": len(symptom_counts),
            "unique_remedies_found": len(remedy_counts),
            "most_discussed_symptom": top_symptoms[0] if top_symptoms else "none",
            "most_popular_remedy": top_remedies[0] if top_remedies else "none"
        }
    }
    
    return result

if __name__ == "__main__":
    result = analyze_reddit_remedies("sample_reddit_data.json")
    
    print(json.dumps(result, indent=2))
    
    with open("analysis_results.json", "w") as f:
        json.dump(result, f, indent=2)
    
    print("\nAnalysis complete! Results saved to 'analysis_results.json'")