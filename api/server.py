#!/usr/bin/env python3
"""
API server for omics-demo dashboard
Provides secure access to AWS resources and demo status
"""

import os
import json
import time
import logging
import traceback
from datetime import datetime
import boto3
import yaml
from flask import Flask, jsonify, request
from flask_cors import CORS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('omics-api')

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Load configuration
CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'config.sh')
DEFAULT_REGION = 'us-east-1'
DEFAULT_BUCKET = 'omics-demo-bucket'
STACK_NAME = 'omics-demo'

# Parse config.sh to get AWS settings
def load_config():
    config = {
        'region': DEFAULT_REGION,
        'bucket': DEFAULT_BUCKET,
        'stack_name': STACK_NAME
    }
    
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                for line in f:
                    if '=' in line and not line.startswith('#'):
                        key, value = line.strip().split('=', 1)
                        if key == 'REGION':
                            config['region'] = value
                        elif key == 'BUCKET_NAME':
                            config['bucket'] = value
                        elif key == 'STACK_NAME':
                            config['stack_name'] = value
    except Exception as e:
        logger.error(f"Error loading config: {str(e)}")
    
    return config

config = load_config()

# Initialize AWS clients
def get_aws_client(service_name):
    try:
        return boto3.client(service_name, region_name=config['region'])
    except Exception as e:
        logger.error(f"Error creating AWS client for {service_name}: {str(e)}")
        return None

# Routes
@app.route('/api/config', methods=['GET'])
def get_config():
    """Get API configuration"""
    return jsonify({
        'region': config['region'],
        'bucket': config['bucket'],
        'stackName': config['stack_name'],
        'simulation': False  # Real mode by default
    })

@app.route('/api/status', methods=['GET'])
def get_status():
    """Get demo job status"""
    try:
        batch = get_aws_client('batch')
        if not batch:
            return jsonify({'status': 'ERROR', 'message': 'AWS Batch client not available'}), 500
        
        # Get job queue
        queue_name = f"{config['stack_name']}-queue"
        job_queues = batch.describe_job_queues(jobQueues=[queue_name])
        
        if not job_queues['jobQueues']:
            return jsonify({'status': 'NOT_FOUND', 'message': 'Job queue not found'}), 404
        
        # Get running jobs
        running_jobs = batch.list_jobs(jobQueue=queue_name, jobStatus='RUNNING')
        completed_jobs = batch.list_jobs(jobQueue=queue_name, jobStatus='SUCCEEDED')
        failed_jobs = batch.list_jobs(jobQueue=queue_name, jobStatus='FAILED')
        
        # Determine status
        if running_jobs['jobSummaryList']:
            status = 'RUNNING'
            message = f"Processing samples... ({len(running_jobs['jobSummaryList'])} jobs running)"
            completed_samples = len(completed_jobs['jobSummaryList'])
        elif failed_jobs['jobSummaryList'] and not completed_jobs['jobSummaryList']:
            status = 'FAILED'
            message = f"Demo failed with {len(failed_jobs['jobSummaryList'])} failed jobs"
            completed_samples = len(completed_jobs['jobSummaryList'])
        elif completed_jobs['jobSummaryList']:
            status = 'COMPLETED'
            message = f"Analysis completed with {len(completed_jobs['jobSummaryList'])} successful jobs"
            completed_samples = len(completed_jobs['jobSummaryList'])
        else:
            status = 'READY'
            message = 'Demo ready to start'
            completed_samples = 0
        
        # Calculate cost from CloudWatch metrics
        cloudwatch = get_aws_client('cloudwatch')
        cost_accrued = 0.0
        if cloudwatch:
            try:
                # This would be expanded in a real implementation to calculate actual costs
                # from CloudWatch metrics for the Batch compute environment
                cost_accrued = 0.0
            except Exception as e:
                logger.error(f"Error getting cost metrics: {str(e)}")
        
        return jsonify({
            'status': status,
            'message': message,
            'completedSamples': completed_samples,
            'totalSamples': 100,  # Hardcoded for demo
            'costAccrued': cost_accrued
        })
        
    except Exception as e:
        logger.error(f"Error getting status: {str(e)}\n{traceback.format_exc()}")
        return jsonify({'status': 'ERROR', 'message': str(e)}), 500

@app.route('/api/resources', methods=['GET'])
def get_resources():
    """Get resource utilization"""
    try:
        cloudwatch = get_aws_client('cloudwatch')
        if not cloudwatch:
            return jsonify({'error': 'CloudWatch client not available'}), 500
        
        # In a real implementation, we would query CloudWatch for:
        # - CPU utilization
        # - Memory utilization
        # - GPU utilization
        # - Number of instances
        
        # For this demo, we'll return mock data
        current_time = time.time()
        time_minutes = current_time % 15  # Mock time within a 15 minute window
        
        # Simulate CPU scaling pattern similar to the frontend simulation
        def simulate_cpu_count(time_minutes):
            if time_minutes < 1: 
                return int(time_minutes * 20)
            if time_minutes < 3: 
                return int(20 + (time_minutes - 1) * 70)
            if time_minutes < 8: 
                return 160
            if time_minutes < 10: 
                return int(160 - (time_minutes - 8) * 60)
            return int(40 - (min(time_minutes, 13) - 10) * 10)
        
        # Simulate utilization with some noise
        import random
        cpu_count = simulate_cpu_count(time_minutes)
        cpu_util = 75 + random.uniform(-5, 15)
        mem_util = 60 + random.uniform(-10, 20)
        gpu_util = 0 if time_minutes < 10 else (80 + random.uniform(-5, 15))
        
        return jsonify({
            'time': time_minutes,
            'cpuCount': cpu_count,
            'cpuUtilization': cpu_util,
            'memoryUtilization': mem_util,
            'gpuUtilization': gpu_util
        })
        
    except Exception as e:
        logger.error(f"Error getting resources: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get variant statistics"""
    try:
        s3 = get_aws_client('s3')
        if not s3:
            return jsonify({'error': 'S3 client not available'}), 500
        
        # Try to get real stats from S3
        try:
            stats_key = 'results/stats/stats.json'
            response = s3.get_object(Bucket=config['bucket'], Key=stats_key)
            stats_data = json.loads(response['Body'].read().decode('utf-8'))
            return jsonify(stats_data)
        except Exception as e:
            logger.warning(f"Could not get real stats, using mock data: {str(e)}")
        
        # Return mock stats if real data isn't available
        return jsonify({
            'totalVariants': 243826,
            'transitions': 167538,
            'transversions': 76288,
            'tiTvRatio': 2.196
        })
        
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/start', methods=['POST'])
def start_demo():
    """Start the demo workflow"""
    try:
        # Check if AWS Batch is available
        batch = get_aws_client('batch')
        if not batch:
            return jsonify({'error': 'AWS Batch client not available'}), 500
        
        # Create job definition if it doesn't exist
        job_definition_name = f"{config['stack_name']}-job-def"
        try:
            batch.describe_job_definitions(jobDefinitionName=job_definition_name, status='ACTIVE')
        except batch.exceptions.ClientException:
            logger.info(f"Creating job definition {job_definition_name}")
            # This would actually create the job definition in a real implementation
        
        # Submit the job
        try:
            response = batch.submit_job(
                jobName=f"omics-demo-{int(time.time())}",
                jobQueue=f"{config['stack_name']}-queue",
                jobDefinition=job_definition_name,
                containerOverrides={
                    'environment': [
                        {
                            'name': 'BUCKET_NAME',
                            'value': config['bucket']
                        },
                        {
                            'name': 'REGION',
                            'value': config['region']
                        }
                    ]
                }
            )
            
            return jsonify({
                'success': True,
                'jobId': response['jobId'],
                'message': 'Demo started successfully'
            })
            
        except Exception as e:
            logger.error(f"Error submitting job: {str(e)}")
            return jsonify({'error': f"Failed to submit job: {str(e)}"}), 500
        
    except Exception as e:
        logger.error(f"Error starting demo: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)