"""
Flask API Server for Face Recognition
Serves the FirebaseFaceModel from lib/ai/ via HTTP endpoints.
"""

import sys
import os
import io
import base64
import tempfile
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image, ImageOps, ImageEnhance
import face_recognition
import numpy as np

# Add project root to path so we can import from lib/ai
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# Add backend directory to path so the AI model can find app.services.firebase_service
backend_path = os.path.abspath(os.path.dirname(__file__))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

from lib.ai.firebase_face_model import FirebaseFaceModel

app = Flask(__name__)
CORS(app)

# Initialize the face model
face_model = FirebaseFaceModel()


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'ok',
        'model_loaded': len(face_model.known_face_encodings) > 0,
        'known_faces': len(face_model.known_face_encodings),
        'names': face_model.known_face_names,
    })


@app.route('/api/reload', methods=['POST'])
def reload_model():
    """Reload face encodings from Firebase."""
    try:
        success = face_model.reload()
        return jsonify({
            'success': success,
            'known_faces': len(face_model.known_face_encodings),
            'names': face_model.known_face_names,
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/recognize', methods=['POST'])
def recognize_face():
    """
    Recognize a face from a base64 image.
    
    Request body:
    {
        "image": "base64_encoded_image_string"
    }
    
    Response:
    {
        "success": true/false,
        "recognized": true/false,
        "name": "matched_name" or null,
        "user_id": "matched_user_id" or null,
        "message": "status message",
        "confidence": 0.0-1.0
    }
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({
                'success': False,
                'error': 'No image provided. Send {"image": "base64_string"}'
            }), 400

        image_base64 = data['image']

        # Strip data URI prefix if present
        if ',' in image_base64:
            image_base64 = image_base64.split(',')[1]

        # Decode base64 to temp file for recognition
        image_bytes = base64.b64decode(image_base64)
        
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            tmp.write(image_bytes)
            tmp_path = tmp.name

        try:
            # Run face recognition
            name, message = face_model.recognize_face(tmp_path)
            
            if name is not None:
                # Find the user ID for the matched name
                user_id = None
                for i, known_name in enumerate(face_model.known_face_names):
                    if known_name == name:
                        user_id = face_model.known_face_ids[i]
                        break
                
                # Extract confidence from message (format: "Recognized: Name (XX%)")
                confidence = 0.0
                if '(' in message and '%' in message:
                    try:
                        conf_str = message.split('(')[1].split('%')[0]
                        confidence = float(conf_str) / 100.0
                    except (IndexError, ValueError):
                        confidence = 0.0

                return jsonify({
                    'success': True,
                    'recognized': True,
                    'name': name,
                    'user_id': user_id,
                    'message': message,
                    'confidence': confidence,
                })
            else:
                return jsonify({
                    'success': True,
                    'recognized': False,
                    'name': None,
                    'user_id': None,
                    'message': message,
                    'confidence': 0.0,
                })
        finally:
            # Clean up temp file
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e),
        }), 500


@app.route('/api/register', methods=['POST'])
def register_face():
    """
    Register a new face encoding for an employee.
    
    Request body:
    {
        "name": "Employee Name",
        "numeric_id": "employee_numeric_id",
        "image": "base64_encoded_image_string"
    }
    
    Response:
    {
        "success": true/false,
        "message": "status message"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400

        name = data.get('name')
        numeric_id = data.get('numeric_id')
        image_base64 = data.get('image')

        if not all([name, numeric_id, image_base64]):
            return jsonify({
                'success': False,
                'error': 'Missing required fields: name, numeric_id, image'
            }), 400

        success, message = face_model.add_employee(name, numeric_id, image_base64)

        return jsonify({
            'success': success,
            'message': message,
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e),
        }), 500


@app.route('/api/generate-encoding', methods=['POST'])
def generate_encoding():
    """
    Generate a face encoding from a base64 image without registering.
    Useful for getting the encoding to store separately.
    
    Request body:
    {
        "image": "base64_encoded_image_string"
    }
    
    Response:
    {
        "success": true/false,
        "encoding": [128 float values] or null,
        "message": "status message"
    }
    """
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({'success': False, 'error': 'No image provided'}), 400

        image_base64 = data['image']
        encoding, message = face_model.generate_encoding_from_base64(image_base64)

        if encoding is not None:
            return jsonify({
                'success': True,
                'encoding': encoding.tolist(),
                'message': message,
            })
        else:
            return jsonify({
                'success': False,
                'encoding': None,
                'message': message,
            })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e),
        }), 500


@app.route('/api/train', methods=['POST'])
def train_face():
    """
    Train face model with multiple images for a user.
    Generates encodings from each image, averages them for robustness,
    and stores the averaged encoding in Firebase.

    Request body:
    {
        "user_id": "employee_numeric_id",
        "name": "Employee Name",
        "images": ["base64_image_1", "base64_image_2", ...]
    }

    Response:
    {
        "success": true/false,
        "message": "status message",
        "encodings_generated": number_of_successful_encodings,
        "total_images": number_of_images_sent
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400

        user_id = data.get('user_id')
        name = data.get('name')
        images = data.get('images', [])

        if not user_id or not name:
            return jsonify({
                'success': False,
                'error': 'Missing required fields: user_id, name'
            }), 400

        if not images or len(images) < 1:
            return jsonify({
                'success': False,
                'error': 'At least 1 training image is required'
            }), 400

        print(f"\n=== Training face for {name} (ID: {user_id}) ===")
        print(f"Received {len(images)} training images")

        # Generate encodings from each image
        encodings = []
        for i, img_base64 in enumerate(images):
            encoding, message = face_model.generate_encoding_from_base64(img_base64)
            if encoding is not None:
                encodings.append(encoding)
                print(f"  Image {i+1}: [+] Encoding generated")
            else:
                print(f"  Image {i+1}: [-] {message}")

        if not encodings:
            return jsonify({
                'success': False,
                'message': 'Could not generate encoding from any image. Please ensure your face is clearly visible.',
                'encodings_generated': 0,
                'total_images': len(images),
            }), 400

        # Average all encodings for a robust representation
        averaged_encoding = np.mean(encodings, axis=0)
        print(f"Averaged {len(encodings)} encodings into one robust encoding")

        # Store in Firebase
        firebase_error = None
        if face_model.firebase_service.firebase_enabled and face_model.firebase_service.db is not None:
            try:
                import datetime
                users_ref = face_model.firebase_service.db.collection('users')
                query = users_ref.where('numericId', '==', user_id).limit(1)
                existing = list(query.stream())

                encoding_list = averaged_encoding.tolist()

                if existing:
                    existing[0].reference.update({
                        'faceEncoding': encoding_list,
                        'faceTrainedAt': datetime.datetime.now().isoformat(),
                        'trainingImageCount': len(encodings),
                    })
                else:
                    users_ref.add({
                        'name': name,
                        'numericId': user_id,
                        'faceEncoding': encoding_list,
                        'faceTrainedAt': datetime.datetime.now().isoformat(),
                        'trainingImageCount': len(encodings),
                    })
            except Exception as e:
                print(f"Failed to save to Firebase: {str(e)}")
                firebase_error = str(e)
        else:
            print("Firebase is disabled. Skipping database save, updating in-memory only.")
            firebase_error = "Firebase not initialized"

        try:
            # Update runtime model - remove old entries for this user first
            indices_to_remove = [
                i for i, uid in enumerate(face_model.known_face_ids)
                if uid == user_id
            ]
            for i in sorted(indices_to_remove, reverse=True):
                face_model.known_face_encodings.pop(i)
                face_model.known_face_names.pop(i)
                face_model.known_face_ids.pop(i)

            # Add the new averaged encoding
            face_model.known_face_encodings.append(averaged_encoding)
            face_model.known_face_names.append(name)
            face_model.known_face_ids.append(user_id)

            print(f"[+] Training complete for {name}")

            # Return success even if firebase failed, since it's now trained in-memory
            return jsonify({
                'success': True,
                'message': f'Face training completed for {name}. Used {len(encodings)}/{len(images)} images.',
                'encodings_generated': len(encodings),
                'total_images': len(images),
                'firebase_error': firebase_error
            })

        except Exception as e:
            return jsonify({
                'success': False,
                'error': f'Runtime model update error: {str(e)}',
            }), 500

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e),
        }), 500


@app.route('/api/verify', methods=['POST'])
def verify_face():
    """
    Verify a face against a specific user.
    Checks face count and whether the face matches the expected user.

    Request body:
    {
        "user_id": "expected_employee_numeric_id",
        "image": "base64_encoded_image_string"
    }

    Response:
    {
        "success": true/false,
        "face_count": number_of_faces_detected,
        "match": true/false,
        "matched_name": "name" or null,
        "matched_user_id": "id" or null,
        "confidence": 0.0-1.0,
        "error_type": null | "no_face" | "multiple_faces" | "mismatch" | "not_recognized" | "not_trained",
        "message": "status message"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400

        user_id = data.get('user_id')
        image_base64 = data.get('image')

        if not user_id or not image_base64:
            return jsonify({
                'success': False,
                'error': 'Missing required fields: user_id, image'
            }), 400

        # Strip data URI prefix if present
        if ',' in image_base64:
            image_base64 = image_base64.split(',')[1]

        print(f"\n=== Verifying face for user_id: {user_id} ===")

        # Check if the user has been trained
        user_trained = user_id in face_model.known_face_ids
        if not user_trained:
            print(f"[-] User {user_id} has not been trained")
            return jsonify({
                'success': False,
                'face_count': 0,
                'match': False,
                'matched_name': None,
                'matched_user_id': None,
                'confidence': 0.0,
                'error_type': 'not_trained',
                'message': 'Face not trained. Please register your face first.',
            })

        # Decode image
        image_bytes = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_bytes))
        image = ImageOps.exif_transpose(image) # Fix mobile camera rotation
        
        if image.mode != 'RGB':
            image = image.convert('RGB')

        # Enhance image
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(1.2)

        image_array = np.array(image)

        # Detect all faces
        face_locations = face_recognition.face_locations(image_array, model='hog')
        face_count = len(face_locations)
        print(f"Detected {face_count} face(s)")

        # Handle: no face
        if face_count == 0:
            return jsonify({
                'success': False,
                'face_count': 0,
                'match': False,
                'matched_name': None,
                'matched_user_id': None,
                'confidence': 0.0,
                'error_type': 'no_face',
                'message': 'No face detected in the image.',
            })

        # Handle: multiple faces
        if face_count > 1:
            return jsonify({
                'success': False,
                'face_count': face_count,
                'match': False,
                'matched_name': None,
                'matched_user_id': None,
                'confidence': 0.0,
                'error_type': 'multiple_faces',
                'message': f'{face_count} faces detected. Only one face should be visible.',
            })

        # Exactly 1 face - generate encoding
        face_encodings = face_recognition.face_encodings(
            image_array, known_face_locations=face_locations, model='large'
        )

        if not face_encodings:
            return jsonify({
                'success': False,
                'face_count': 1,
                'match': False,
                'matched_name': None,
                'matched_user_id': None,
                'confidence': 0.0,
                'error_type': 'no_face',
                'message': 'Could not generate face encoding.',
            })

        face_encoding = face_encodings[0]

        # Compare against all known faces
        known_encodings_array = np.array(face_model.known_face_encodings)
        face_distances = face_recognition.face_distance(known_encodings_array, face_encoding)
        matches = face_recognition.compare_faces(known_encodings_array, face_encoding, tolerance=0.45)

        best_match_index = np.argmin(face_distances)
        best_confidence = max(0, 1 - face_distances[best_match_index])

        if matches[best_match_index] and best_confidence >= 0.55:
            matched_name = face_model.known_face_names[best_match_index]
            matched_id = face_model.known_face_ids[best_match_index]

            # Check if the matched person is the expected user
            if matched_id == user_id:
                print(f"[+] Match confirmed: {matched_name} ({best_confidence:.0%})")
                return jsonify({
                    'success': True,
                    'face_count': 1,
                    'match': True,
                    'matched_name': matched_name,
                    'matched_user_id': matched_id,
                    'confidence': round(best_confidence, 4),
                    'error_type': None,
                    'message': f'Face verified: {matched_name} ({best_confidence:.0%})',
                })
            else:
                # Face recognized but belongs to someone else
                print(f"[-] Mismatch: recognized {matched_name} but expected user_id {user_id}")
                return jsonify({
                    'success': False,
                    'face_count': 1,
                    'match': False,
                    'matched_name': matched_name,
                    'matched_user_id': matched_id,
                    'confidence': round(best_confidence, 4),
                    'error_type': 'mismatch',
                    'message': f'Face does not match account owner. Detected: {matched_name}',
                })
        else:
            # Face not recognized at all
            print(f"[-] Face not recognized (best confidence: {best_confidence:.0%})")
            return jsonify({
                'success': False,
                'face_count': 1,
                'match': False,
                'matched_name': None,
                'matched_user_id': None,
                'confidence': round(best_confidence, 4),
                'error_type': 'not_recognized',
                'message': 'Face not recognized. Please ensure good lighting and face the camera directly.',
            })

    except Exception as e:
        print(f"Verify error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e),
        }), 500


def import_datetime_now():
    """Helper to get current timestamp as ISO string."""
    from datetime import datetime
    return datetime.now().isoformat()


if __name__ == '__main__':
    print("=" * 50)
    print("  Face Recognition API Server")
    print("=" * 50)

    # Load face encodings from Firebase on startup
    print("\nLoading face encodings from Firebase...")
    loaded = face_model.load_from_firebase()
    if loaded:
        print(f"✓ Loaded {len(face_model.known_face_encodings)} face(s)".encode('ascii', 'ignore').decode('ascii'))
    else:
        print("WARNING: No faces loaded - register employees first")

    print(f"\nServer starting on http://0.0.0.0:5000")
    print("Endpoints:")
    print("  GET  /api/health            - Health check")
    print("  POST /api/recognize         - Recognize a face")
    print("  POST /api/register          - Register a new face")
    print("  POST /api/reload            - Reload encodings from Firebase")
    print("  POST /api/generate-encoding - Generate encoding without registering")
    print("  POST /api/train             - Train with multiple images")
    print("  POST /api/verify            - Verify face against specific user")
    print("=" * 50)

    app.run(host='0.0.0.0', port=5000, debug=True)
