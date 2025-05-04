"""Pytest configuration file for omics-demo tests."""
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.

import os
import sys
import pytest
from flask import Flask

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


@pytest.fixture
def app():
    """Create a Flask app for testing."""
    from api.server import app as flask_app
    flask_app.config.update({
        "TESTING": True,
    })
    
    # Configure test environment
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
    os.environ["BUCKET_NAME"] = "test-bucket"
    os.environ["STACK_NAME"] = "test-stack"
    
    yield flask_app
    
    # Cleanup


@pytest.fixture
def client(app):
    """Create a test client for the Flask app."""
    return app.test_client()


@pytest.fixture
def runner(app):
    """Create a test CLI runner for Flask commands."""
    return app.test_cli_runner()