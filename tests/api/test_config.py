"""Test the API configuration endpoint."""

import json


def test_config_endpoint(client):
    """Test that the config endpoint returns expected values."""
    response = client.get("/api/config")
    assert response.status_code == 200
    
    data = json.loads(response.data)
    assert "region" in data
    assert "bucket" in data
    assert "stackName" in data
    assert "simulation" in data
    assert data["simulation"] is False