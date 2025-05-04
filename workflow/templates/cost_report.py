#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
"""
Cost Report Generator for Omics Demo
Calculates cost savings compared to traditional on-premises approaches
"""

import os
import sys
import json
import argparse
import datetime
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# Constants for cost calculations
COST_CONSTANTS = {
    "on_prem": {
        "server_cost_per_hour": 1.20,  # Standard on-prem genomics server
        "startup_time_hours": 336,     # 2 weeks typical setup time
        "maintenance_cost_per_hour": 0.45,
        "power_cooling_per_hour": 0.35,
    },
    "aws": {
        "graviton3_cost_per_hour": 0.136,  # c7g.2xlarge
        "x86_cost_per_hour": 0.192,        # c6i.2xlarge
        "spot_discount": 0.70,             # 70% discount for spot
        "s3_cost_per_gb_month": 0.023,
        "batch_overhead_cost": 0.0,        # No additional charge for AWS Batch
    }
}

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Generate cost report for Omics Demo')
    parser.add_argument('--output-dir', type=str, default='./results',
                      help='Directory to save the cost report (default: ./results)')
    parser.add_argument('--samples', type=int, default=100,
                      help='Number of samples processed (default: 100)')
    parser.add_argument('--runtime-minutes', type=float, default=15,
                      help='Total runtime in minutes (default: 15)')
    parser.add_argument('--spot-percentage', type=float, default=95,
                      help='Percentage of instances using spot pricing (default: 95)')
    parser.add_argument('--graviton-percentage', type=float, default=90,
                      help='Percentage of instances using Graviton (default: 90)')
    parser.add_argument('--instance-count', type=int, default=160,
                      help='Maximum number of instances used (default: 160)')
    
    return parser.parse_args()

def calculate_costs(args):
    """Calculate costs for both on-premises and AWS approaches."""
    # Convert runtime to hours for calculations
    runtime_hours = args.runtime_minutes / 60
    
    # Calculate instance hours (scaled for actual usage patterns)
    # In reality, instances scale from 0 to max and back down
    effective_instance_hours = args.instance_count * runtime_hours * 0.6  # ~60% avg utilization
    
    # Calculate instance type distribution
    spot_hours = effective_instance_hours * (args.spot_percentage / 100)
    on_demand_hours = effective_instance_hours * (1 - args.spot_percentage / 100)
    
    graviton_hours = effective_instance_hours * (args.graviton_percentage / 100)
    x86_hours = effective_instance_hours * (1 - args.graviton_percentage / 100)
    
    # Combine pricing models for total cost
    spot_graviton_hours = spot_hours * (args.graviton_percentage / 100)
    spot_x86_hours = spot_hours * (1 - args.graviton_percentage / 100)
    od_graviton_hours = on_demand_hours * (args.graviton_percentage / 100)
    od_x86_hours = on_demand_hours * (1 - args.graviton_percentage / 100)
    
    # Calculate AWS costs
    graviton_cost = COST_CONSTANTS["aws"]["graviton3_cost_per_hour"]
    x86_cost = COST_CONSTANTS["aws"]["x86_cost_per_hour"]
    spot_discount = COST_CONSTANTS["aws"]["spot_discount"]
    
    spot_graviton_cost = spot_graviton_hours * graviton_cost * (1 - spot_discount)
    spot_x86_cost = spot_x86_hours * x86_cost * (1 - spot_discount)
    od_graviton_cost = od_graviton_hours * graviton_cost
    od_x86_cost = od_x86_hours * x86_cost
    
    # Storage costs (rough estimate)
    storage_cost = 100 * COST_CONSTANTS["aws"]["s3_cost_per_gb_month"] / 30  # 100GB for ~1 day
    
    # Total AWS cost
    aws_cost = spot_graviton_cost + spot_x86_cost + od_graviton_cost + od_x86_cost + storage_cost
    
    # On-premises calculation - traditional approach
    # For 100 samples, typical on-prem time is ~2 weeks (336 hours)
    onprem_runtime_hours = 336  # 14 days * 24 hours
    onprem_servers = max(1, int(args.samples / 25))  # 1 server per 25 samples
    
    server_cost = onprem_servers * onprem_runtime_hours * COST_CONSTANTS["on_prem"]["server_cost_per_hour"]
    maintenance_cost = onprem_servers * onprem_runtime_hours * COST_CONSTANTS["on_prem"]["maintenance_cost_per_hour"]
    power_cooling_cost = onprem_servers * onprem_runtime_hours * COST_CONSTANTS["on_prem"]["power_cooling_per_hour"]
    
    # Total on-premises cost
    onprem_cost = server_cost + maintenance_cost + power_cooling_cost
    
    return {
        "aws": {
            "total_cost": aws_cost,
            "compute_cost": spot_graviton_cost + spot_x86_cost + od_graviton_cost + od_x86_cost,
            "storage_cost": storage_cost,
            "runtime_hours": runtime_hours,
            "instance_hours": effective_instance_hours,
            "spot_percentage": args.spot_percentage,
            "graviton_percentage": args.graviton_percentage
        },
        "on_prem": {
            "total_cost": onprem_cost,
            "compute_cost": server_cost,
            "maintenance_cost": maintenance_cost,
            "power_cooling_cost": power_cooling_cost,
            "runtime_hours": onprem_runtime_hours,
            "server_count": onprem_servers
        },
        "savings": {
            "cost_savings": onprem_cost - aws_cost,
            "percentage_savings": (onprem_cost - aws_cost) / onprem_cost * 100,
            "time_savings_hours": onprem_runtime_hours - runtime_hours,
            "time_savings_percentage": (onprem_runtime_hours - runtime_hours) / onprem_runtime_hours * 100
        }
    }

def generate_charts(cost_data, output_dir):
    """Generate charts for the cost report."""
    # Create output directory if it doesn't exist
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    # Cost comparison chart
    plt.figure(figsize=(10, 6))
    labels = ['AWS', 'On-Premises']
    costs = [cost_data['aws']['total_cost'], cost_data['on_prem']['total_cost']]
    colors = ['#FF9900', '#232F3E']  # AWS colors
    
    plt.bar(labels, costs, color=colors)
    plt.title('Cost Comparison: AWS vs On-Premises')
    plt.ylabel('Cost (USD)')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Add cost values on top of bars
    for i, cost in enumerate(costs):
        plt.text(i, cost + 50, f'${cost:.2f}', ha='center', fontweight='bold')
    
    # Add savings callout
    savings_pct = cost_data['savings']['percentage_savings']
    plt.figtext(0.5, 0.01, f'Cost Savings: ${cost_data["savings"]["cost_savings"]:.2f} ({savings_pct:.1f}%)',
                ha='center', fontsize=12, bbox={'facecolor':'#E6F2F8', 'alpha':0.8, 'pad':5})
    
    plt.savefig(f'{output_dir}/cost_comparison.png', dpi=300, bbox_inches='tight')
    
    # Time comparison chart
    plt.figure(figsize=(10, 6))
    labels = ['AWS', 'On-Premises']
    times = [cost_data['aws']['runtime_hours'], cost_data['on_prem']['runtime_hours']]
    
    plt.bar(labels, times, color=colors)
    plt.title('Time Comparison: AWS vs On-Premises')
    plt.ylabel('Runtime (hours)')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Add time values on top of bars
    for i, time in enumerate(times):
        plt.text(i, time + 10, f'{time:.1f} hours', ha='center', fontweight='bold')
    
    # Add time savings callout
    time_savings_pct = cost_data['savings']['time_savings_percentage']
    plt.figtext(0.5, 0.01, 
                f'Time Savings: {cost_data["savings"]["time_savings_hours"]:.1f} hours ({time_savings_pct:.1f}%)',
                ha='center', fontsize=12, bbox={'facecolor':'#E6F2F8', 'alpha':0.8, 'pad':5})
    
    plt.savefig(f'{output_dir}/time_comparison.png', dpi=300, bbox_inches='tight')
    
    # Cost breakdown chart for AWS
    plt.figure(figsize=(8, 8))
    aws_labels = ['Compute', 'Storage']
    aws_costs = [cost_data['aws']['compute_cost'], cost_data['aws']['storage_cost']]
    
    plt.pie(aws_costs, labels=aws_labels, autopct='%1.1f%%', startangle=90, colors=['#FF9900', '#146EB4'])
    plt.axis('equal')
    plt.title('AWS Cost Breakdown')
    plt.savefig(f'{output_dir}/aws_cost_breakdown.png', dpi=300, bbox_inches='tight')
    
    # Cost breakdown chart for on-premises
    plt.figure(figsize=(8, 8))
    onprem_labels = ['Servers', 'Maintenance', 'Power & Cooling']
    onprem_costs = [
        cost_data['on_prem']['compute_cost'], 
        cost_data['on_prem']['maintenance_cost'],
        cost_data['on_prem']['power_cooling_cost']
    ]
    
    plt.pie(onprem_costs, labels=onprem_labels, autopct='%1.1f%%', startangle=90, 
            colors=['#232F3E', '#7D8998', '#99BCE3'])
    plt.axis('equal')
    plt.title('On-Premises Cost Breakdown')
    plt.savefig(f'{output_dir}/onprem_cost_breakdown.png', dpi=300, bbox_inches='tight')

def main():
    """Main function."""
    args = parse_arguments()
    cost_data = calculate_costs(args)
    
    # Generate report
    generate_charts(cost_data, args.output_dir)
    
    # Save the data as JSON
    with open(f'{args.output_dir}/cost_report.json', 'w') as f:
        json.dump(cost_data, f, indent=2)
    
    # Print summary to stdout
    print("Cost Report Summary:")
    print("===================")
    print(f"AWS Total Cost: ${cost_data['aws']['total_cost']:.2f}")
    print(f"On-Premises Total Cost: ${cost_data['on_prem']['total_cost']:.2f}")
    print(f"Savings: ${cost_data['savings']['cost_savings']:.2f} ({cost_data['savings']['percentage_savings']:.1f}%)")
    print(f"Time Reduction: {cost_data['savings']['time_savings_hours']:.1f} hours ({cost_data['savings']['time_savings_percentage']:.1f}%)")
    print("===================")
    print(f"Report saved to {args.output_dir}/")

if __name__ == "__main__":
    main()