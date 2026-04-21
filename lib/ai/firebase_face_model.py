import face_recognition
import numpy as np
import sys
import os
import os
from PIL import Image, ImageEnhance, ImageOps
import io
import base64

backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend'))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)
from app.services.firebase_service import FirebaseService

class FirebaseFaceModel:
    def __init__(self):
        self.known_face_encodings = []
        self.known_face_names = []
        self.known_face_ids = []
        self.firebase_service = FirebaseService()
        
    def load_from_firebase(self):
        """Load all encodings from Firebase users collection"""
        if not self.firebase_service.firebase_enabled:
            print("Firebase disabled - cannot load encodings")
            return False
            
        try:
            users_ref = self.firebase_service.db.collection('users')
            docs = users_ref.stream()
            
            count = 0
            for doc in docs:
                user_data = doc.to_dict()
                name = user_data.get('name')
                user_id = user_data.get('numericId')
                encoding_data = user_data.get('faceEncoding')
                
                if encoding_data and name:
                    try:
                        # Check if encoding is base64 string
                        if isinstance(encoding_data, str):
                            encoding_bytes = base64.b64decode(encoding_data)
                            encoding = np.frombuffer(encoding_bytes, dtype=np.float64)
                        else:
                            encoding = np.array(encoding_data, dtype=np.float64)
                        
                        # Validate encoding shape (should be 128 dimensions)
                        if encoding.shape != (128,):
                            print(f"Skipped {name}: Invalid encoding shape {encoding.shape}")
                            continue
                        
                        self.known_face_encodings.append(encoding)
                        self.known_face_names.append(name)
                        self.known_face_ids.append(user_id)
                        count += 1
                        print(f"Loaded: {name}")
                    except Exception as e:
                        print(f"Skipped {name}: {str(e)}")
                        continue
            
            print(f"Loaded {count} encodings from Firebase")
            return count > 0
            
        except Exception as e:
            print(f"Error loading from Firebase: {e}")
            return False
    
    def generate_encoding_from_base64(self, image_base64):
        """Generate face encoding from base64 image"""
        try:
            if ',' in image_base64:
                image_base64 = image_base64.split(',')[1]
            
            image_bytes = base64.b64decode(image_base64)
            image = Image.open(io.BytesIO(image_bytes))
            image = ImageOps.exif_transpose(image) # Fix EXIF rotation from mobile cameras
            
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            enhancer = ImageEnhance.Contrast(image)
            image = enhancer.enhance(1.2)
            
            image_array = np.array(image)
            encodings = face_recognition.face_encodings(image_array, model='large')
            
            if not encodings:
                return None, "No face detected"
            
            if len(encodings) > 1:
                return None, "Multiple faces detected"
            
            return encodings[0], "Success"
            
        except Exception as e:
            return None, f"Error: {str(e)}"
    
    def add_employee(self, name, numeric_id, image_base64):
        """Add new employee directly to Firebase with encoding"""
        encoding, message = self.generate_encoding_from_base64(image_base64)
        
        if encoding is None:
            return False, message
        
        try:
            users_ref = self.firebase_service.db.collection('users')
            
            # Find user by numericId
            query = users_ref.where('numericId', '==', numeric_id).limit(1)
            existing = list(query.stream())
            
            if existing:
                # Update existing user with faceEncoding
                existing[0].reference.update({'faceEncoding': encoding.tolist()})
            else:
                # Create new user (shouldn't happen in normal flow)
                user_data = {
                    'name': name,
                    'numericId': numeric_id,
                    'image': image_base64,
                    'faceEncoding': encoding.tolist()
                }
                users_ref.add(user_data)
            
            # Update runtime model
            self.known_face_encodings.append(encoding)
            self.known_face_names.append(name)
            self.known_face_ids.append(numeric_id)
            
            return True, f"Employee {name} added successfully"
            
        except Exception as e:
            return False, f"Firebase error: {str(e)}"
    
    def recognize_face(self, image_path):
        """Recognize face from image file"""
        try:
            print(f"\n=== Starting face recognition ===")
            print(f"Known faces in database: {len(self.known_face_encodings)}")
            if self.known_face_names:
                print(f"Names: {', '.join(self.known_face_names)}")
            
            image = face_recognition.load_image_file(image_path)
            face_encodings = face_recognition.face_encodings(image, model='large')
            
            if not face_encodings:
                print("❌ No face detected in image")
                return None, "No face detected"
            
            if len(face_encodings) > 1:
                print(f"❌ Multiple faces detected: {len(face_encodings)}")
                return None, "Multiple faces detected"
            
            face_encoding = face_encodings[0]
            print("✓ Face encoding generated")
            
            if len(self.known_face_encodings) == 0:
                print("❌ No employees in database")
                return None, "No employees in database"
            
            # Convert to numpy array for comparison
            known_encodings_array = np.array(self.known_face_encodings)
            face_distances = face_recognition.face_distance(known_encodings_array, face_encoding)
            matches = face_recognition.compare_faces(known_encodings_array, face_encoding, tolerance=0.45)
            
            print(f"Face distances: {face_distances}")
            print(f"Matches: {matches}")
            
            if not any(matches):
                print("❌ No matches found")
                return None, "Face not recognized"
            
            best_match_index = np.argmin(face_distances)
            
            if matches[best_match_index]:
                name = self.known_face_names[best_match_index]
                confidence = max(0, 1 - face_distances[best_match_index])
                
                print(f"Best match: {name} with confidence {confidence:.0%}")
                
                if confidence < 0.55:
                    print(f"❌ Confidence too low: {confidence:.0%}")
                    return None, f"Confidence too low ({confidence:.0%})"
                
                print(f"✓ Recognition successful: {name}")
                return name, f"Recognized: {name} ({confidence:.0%})"
            
            print("❌ No match found")
            return None, "No match found"
            
        except Exception as e:
            print(f"❌ Error: {str(e)}")
            return None, f"Error: {str(e)}"
    
    def reload(self):
        """Reload all encodings from Firebase"""
        self.known_face_encodings = []
        self.known_face_names = []
        self.known_face_ids = []
        return self.load_from_firebase()
