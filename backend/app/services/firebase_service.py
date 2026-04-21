import firebase_admin
from firebase_admin import credentials, firestore
import os


class FirebaseService:
    """Firebase Admin SDK service for backend access to Firestore."""

    def __init__(self):
        self.firebase_enabled = False
        self.db = None
        self._initialize()

    def _initialize(self):
        """Initialize Firebase Admin SDK."""
        try:
            # Check if already initialized
            try:
                app = firebase_admin.get_app()
            except ValueError:
                # Not initialized yet - initialize now
                # Option 0: Load from JSON environment variable (for Railway)
                import json
                env_json = os.environ.get('FIREBASE_CREDENTIALS_JSON')
                if env_json:
                    try:
                        cred_dict = json.loads(env_json)
                        cred = credentials.Certificate(cred_dict)
                        app = firebase_admin.initialize_app(cred)
                        print("Firebase initialized with FIREBASE_CREDENTIALS_JSON")
                    except Exception as e:
                        print(f"Failed to parse FIREBASE_CREDENTIALS_JSON: {e}")
                
                # Option 1: Use service account key file
                if not firebase_admin._apps:
                    cred_path = os.environ.get(
                        'FIREBASE_CREDENTIALS',
                        os.path.join(os.path.dirname(__file__), '..', '..', 'serviceAccountKey.json')
                    )
    
                    if os.path.exists(cred_path):
                        cred = credentials.Certificate(cred_path)
                        app = firebase_admin.initialize_app(cred)
                    print(f"Firebase initialized with service account: {cred_path}")
                else:
                    # Option 2: Use Application Default Credentials
                    try:
                        cred = credentials.ApplicationDefault()
                        app = firebase_admin.initialize_app(cred)
                        print("Firebase initialized with Application Default Credentials")
                    except Exception:
                        print("WARNING: No Firebase credentials found.")
                        print(f"  - Place serviceAccountKey.json in: {os.path.dirname(cred_path)}")
                        print("  - Or set FIREBASE_CREDENTIALS environment variable")
                        return

            self.db = firestore.client()
            self.firebase_enabled = True
            print("Firebase Firestore connected successfully")

        except Exception as e:
            print(f"Firebase initialization error: {e}")
            self.firebase_enabled = False
