"""Input validation for API endpoints."""

from functools import wraps
from flask import request, jsonify


def validate_json(schema):
    """Decorator to validate JSON input against a schema.
    
    Args:
        schema: A dict with field names and types or validation functions
        
    Returns:
        A decorator function that validates request.json
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Check if request includes JSON data when required
            if not request.json and schema:
                return jsonify({"error": "Missing JSON in request"}), 400
                
            # Check if all required fields are present
            for field, validator in schema.items():
                if field not in request.json:
                    return jsonify({"error": f"Missing required field: {field}"}), 400
                
                # Validate field value if validator is a function
                if callable(validator):
                    if not validator(request.json[field]):
                        return jsonify({"error": f"Invalid value for field: {field}"}), 400
                # Validate field type if validator is a type
                elif not isinstance(request.json[field], validator):
                    expected_type = validator.__name__
                    actual_type = type(request.json[field]).__name__
                    return jsonify({
                        "error": f"Invalid type for field: {field}. Expected {expected_type}, got {actual_type}"
                    }), 400
            
            return func(*args, **kwargs)
        return wrapper
    return decorator


def is_positive_int(value):
    """Check if value is a positive integer."""
    if not isinstance(value, int):
        return False
    return value > 0


def is_non_empty_string(value):
    """Check if value is a non-empty string."""
    if not isinstance(value, str):
        return False
    return len(value.strip()) > 0


# Validation schemas for API endpoints
START_DEMO_SCHEMA = {
    # Optional fields with their validators
}

# Other schemas as needed