#!/usr/bin/env python3
"""
HealHub Flask Backend
A lightweight Flask API server for managing home remedy data and serving videos
"""

import os
import json
import logging
import re
from datetime import datetime
from functools import wraps
from typing import Dict, List, Optional, Any

import requests
from flask import Flask, jsonify, send_from_directory, Response
from flask_cors import CORS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('healhub.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize Flask app with optimizations for low memory usage
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 300  # Cache static files for 5 minutes
CORS(app)  # Enable CORS for frontend communication

# Constants
REDDIT_URL = "https://www.reddit.com/r/Home_Remedy/comments/.json"
REMEDIES_FILE = "remedies.json"
VIDEOS_DIR = "videos"
USER_AGENT = "HealHub/1.0 (Flask Backend)"

# Create videos directory if it doesn't exist
os.makedirs(VIDEOS_DIR, exist_ok=True)


def handle_errors(f):
    """Decorator for consistent error handling across endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            logger.error(f"Error in {f.__name__}: {str(e)}")
            return jsonify({
                "error": "Internal server error",
                "message": str(e)
            }), 500
    return decorated_function


def extract_remedy_from_post(post: Dict[str, Any], index: int) -> Optional[Dict[str, Any]]:
    """
    Extract remedy information from a Reddit post
    
    Args:
        post: Reddit post data
        index: Index for remedy ID
        
    Returns:
        Dictionary with remedy information or None if extraction fails
    """
    try:
        data = post.get('data', {})
        title = data.get('title', '')
        selftext = data.get('selftext', '')
        score = data.get('score', 0)
        
        # Extract symptom from title using common patterns
        symptom_patterns = [
            r'for\s+(\w+\s*\w*)',
            r'cure\s+(\w+\s*\w*)',
        r'treat\s+(\w+\s*\w*)',
            r'remedy\s+for\s+(\w+\s*\w*)',
            r'help\s+with\s+(\w+\s*\w*)'
        ]
        
        symptom = None
        for pattern in symptom_patterns:
            match = re.search(pattern, title.lower())
            if match:
                symptom = match.group(1).strip()
                break
        
        # If no symptom found in patterns, try to extract from title
        if not symptom:
            # Common symptoms to look for
            common_symptoms = [
                'headache', 'cold', 'flu', 'sore throat', 'cough', 
                'fever', 'stomach', 'pain', 'stress', 'anxiety',
                'insomnia', 'nausea', 'allergy', 'burn', 'cut'
            ]
            
            title_lower = title.lower()
            for s in common_symptoms:
                if s in title_lower:
                    symptom = s
                    break
        
        # Default symptom if none found
        if not symptom:
            symptom = "general wellness"
        
        # Extract remedy name from title
        remedy_title = title.split('-')[0].strip() if '-' in title else title
        remedy_title = remedy_title.split(':')[0].strip() if ':' in remedy_title else remedy_title
        remedy_title = remedy_title[:50]  # Limit length
        
        # Create description from selftext or title
        description = selftext[:200] + "..." if len(selftext) > 200 else selftext
        if not description:
            description = f"Natural remedy for {symptom}. {title}"
        
        # Generate video URL (placeholder)
        video_filename = f"{symptom.replace(' ', '_')}_{index}.mp4"
        
        return {
            "id": index + 1,
            "symptom": symptom,
            "title": remedy_title.lower(),
            "description": description,
            "video": f"/videos/{video_filename}",
            "score": score
        }
    except Exception as e:
        logger.warning(f"Failed to extract remedy from post: {e}")
        return None


def fetch_reddit_data() -> Optional[List[Dict[str, Any]]]:
    """
    Fetch data from Reddit API and extract top remedies
    
    Returns:
        List of remedy dictionaries or None if fetch fails
    """
    try:
        logger.info("Fetching data from Reddit...")
        
        headers = {
            'User-Agent': USER_AGENT
        }
        
        response = requests.get(REDDIT_URL, headers=headers, timeout=10)
        response.raise_for_status()
        
        reddit_data = response.json()
        posts = reddit_data.get('data', {}).get('children', [])
        
        logger.info(f"Fetched {len(posts)} posts from Reddit")
        
        # Extract remedies from posts
        remedies = []
        for i, post in enumerate(posts):
            remedy = extract_remedy_from_post(post, i)
            if remedy:
                remedies.append(remedy)
        
        # Sort by score (upvotes) and get top 10
        remedies.sort(key=lambda x: x.get('score', 0), reverse=True)
        top_remedies = remedies[:10]
        
        # Remove score from final data
        for remedy in top_remedies:
            remedy.pop('score', None)
        
        logger.info(f"Extracted {len(top_remedies)} top remedies")
        return top_remedies
        
    except requests.RequestException as e:
        logger.error(f"Failed to fetch Reddit data: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error while fetching Reddit data: {e}")
        return None


def get_fallback_remedies() -> List[Dict[str, Any]]:
    """
    Return fallback remedy data if Reddit fetch fails
    
    Returns:
        List of default remedy dictionaries
    """
    return [
        {
            "id": 1,
            "symptom": "sore throat",
            "title": "honey and ginger tea",
            "description": "Mix 1 tablespoon of honey with fresh ginger in hot water. Let steep for 10 minutes and drink warm.",
            "video": "/videos/sore_throat_1.mp4"
        },
        {
            "id": 2,
            "symptom": "headache",
            "title": "peppermint oil massage",
            "description": "Apply diluted peppermint oil to temples and massage gently in circular motions for relief.",
            "video": "/videos/headache_2.mp4"
        },
        {
            "id": 3,
            "symptom": "cold",
            "title": "steam inhalation",
            "description": "Inhale steam from hot water with a few drops of eucalyptus oil to clear congestion.",
            "video": "/videos/cold_3.mp4"
        },
        {
            "id": 4,
            "symptom": "stress",
            "title": "chamomile tea",
            "description": "Brew chamomile tea and drink before bedtime to promote relaxation and reduce stress.",
            "video": "/videos/stress_4.mp4"
        },
        {
            "id": 5,
            "symptom": "nausea",
            "title": "ginger root",
            "description": "Chew on fresh ginger root or make ginger tea to settle stomach and reduce nausea.",
            "video": "/videos/nausea_5.mp4"
        },
        {
            "id": 6,
            "symptom": "insomnia",
            "title": "lavender aromatherapy",
            "description": "Place lavender essential oil on pillow or use a diffuser to promote better sleep.",
            "video": "/videos/insomnia_6.mp4"
        },
        {
            "id": 7,
            "symptom": "muscle pain",
            "title": "epsom salt bath",
            "description": "Add 2 cups of Epsom salt to warm bath water and soak for 20 minutes to relieve muscle aches.",
            "video": "/videos/muscle_pain_7.mp4"
        },
        {
            "id": 8,
            "symptom": "sunburn",
            "title": "aloe vera gel",
            "description": "Apply fresh aloe vera gel directly to sunburned skin for cooling relief and healing.",
            "video": "/videos/sunburn_8.mp4"
        },
        {
            "id": 9,
            "symptom": "cough",
            "title": "honey and lemon",
            "description": "Mix equal parts honey and fresh lemon juice. Take 1 tablespoon every few hours.",
            "video": "/videos/cough_9.mp4"
        },
        {
            "id": 10,
            "symptom": "digestive issues",
            "title": "peppermint tea",
            "description": "Steep fresh peppermint leaves in hot water for 5-10 minutes to aid digestion.",
            "video": "/videos/digestive_10.mp4"
        }
    ]


def save_remedies_to_file(remedies: List[Dict[str, Any]]) -> bool:
    """
    Save remedies data to JSON file
    
    Args:
        remedies: List of remedy dictionaries
        
    Returns:
        True if save successful, False otherwise
    """
    try:
        with open(REMEDIES_FILE, 'w', encoding='utf-8') as f:
            json.dump({"remedies": remedies}, f, indent=2, ensure_ascii=False)
        logger.info(f"Saved {len(remedies)} remedies to {REMEDIES_FILE}")
        return True
    except Exception as e:
        logger.error(f"Failed to save remedies to file: {e}")
        return False


def load_remedies_from_file() -> Optional[List[Dict[str, Any]]]:
    """
    Load remedies data from JSON file
    
    Returns:
        List of remedy dictionaries or None if load fails
    """
    try:
        if os.path.exists(REMEDIES_FILE):
            with open(REMEDIES_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('remedies', [])
        return None
    except Exception as e:
        logger.error(f"Failed to load remedies from file: {e}")
        return None


@app.route('/api/remedies', methods=['GET'])
@handle_errors
def get_remedies():
    """
    API endpoint to get all remedies
    
    Returns:
        JSON response with remedies data
    """
    # Try to load from file first
    remedies = load_remedies_from_file()
    
    # If no file exists or load fails, fetch from Reddit
    if not remedies:
        logger.info("No local remedies found, fetching from Reddit...")
        remedies = fetch_reddit_data()
        
        # If Reddit fetch fails, use fallback data
        if not remedies:
            logger.warning("Reddit fetch failed, using fallback remedies")
            remedies = get_fallback_remedies()
        
        # Save to file for future use
        save_remedies_to_file(remedies)
    
    return jsonify({
        "remedies": remedies,
        "count": len(remedies),
        "last_updated": datetime.now().isoformat()
    })


@app.route('/api/remedies/refresh', methods=['POST'])
@handle_errors
def refresh_remedies():
    """
    API endpoint to force refresh remedies from Reddit
    
    Returns:
        JSON response with refresh status
    """
    remedies = fetch_reddit_data()
    
    if remedies:
        save_remedies_to_file(remedies)
        return jsonify({
            "success": True,
            "message": "Remedies refreshed successfully",
            "count": len(remedies)
        })
    else:
        return jsonify({
            "success": False,
            "message": "Failed to refresh remedies from Reddit"
        }), 500


@app.route('/videos/<path:filename>')
@handle_errors
def serve_video(filename):
    """
    Serve video files from the videos directory
    
    Args:
        filename: Name of the video file
        
    Returns:
        Video file or 404 if not found
    """
    # Security: Ensure filename doesn't contain path traversal
    if '..' in filename or '/' in filename:
        return jsonify({"error": "Invalid filename"}), 400
    
    # Check if file exists
    video_path = os.path.join(VIDEOS_DIR, filename)
    if not os.path.exists(video_path):
        logger.warning(f"Video not found: {filename}")
        return jsonify({"error": "Video not found"}), 404
    
    # Serve file with appropriate headers for video streaming
    return send_from_directory(VIDEOS_DIR, filename, mimetype='video/mp4')


@app.route('/health', methods=['GET'])
def health_check():
    """
    Health check endpoint
    
    Returns:
        JSON response with server status
    """
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "remedies_file_exists": os.path.exists(REMEDIES_FILE),
        "videos_directory_exists": os.path.exists(VIDEOS_DIR)
    })


@app.route('/')
def index():
    """
    Root endpoint with API information
    
    Returns:
        JSON response with API details
    """
    return jsonify({
        "app": "HealHub Backend",
        "version": "1.0",
        "endpoints": [
            {"path": "/api/remedies", "method": "GET", "description": "Get all remedies"},
            {"path": "/api/remedies/refresh", "method": "POST", "description": "Refresh remedies from Reddit"},
            {"path": "/videos/<filename>", "method": "GET", "description": "Get video file"},
            {"path": "/health", "method": "GET", "description": "Health check"}
        ]
    })


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({"error": "Internal server error"}), 500


def initialize_app():
    """
    Initialize the application by fetching initial data
    """
    logger.info("Initializing HealHub backend...")
    
    # Check if remedies file already exists
    if not os.path.exists(REMEDIES_FILE):
        logger.info("No existing remedies file found, fetching initial data...")
        remedies = fetch_reddit_data()
        
        if not remedies:
            logger.warning("Failed to fetch Reddit data, using fallback remedies")
            remedies = get_fallback_remedies()
        
        save_remedies_to_file(remedies)
    else:
        logger.info(f"Found existing remedies file: {REMEDIES_FILE}")
    
    logger.info("HealHub backend initialized successfully")


if __name__ == '__main__':
    # Initialize app with data
    initialize_app()
    
    # Run Flask app
    logger.info("Starting HealHub Flask server on port 5000...")
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,  # Set to False in production
        threaded=True,  # Enable threading for better performance
        use_reloader=False  # Disable reloader to reduce memory usage
    )