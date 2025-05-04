// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright 2025 Scott Friedman, All Rights Reserved.
import React, { useState, useEffect } from 'react';
import {
  LineChart, Line, AreaChart, Area, BarChart, Bar, 
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, 
  ResponsiveContainer, PieChart, Pie, Cell
} from 'recharts';
import { demoService } from '../services/api';

// Demo configuration
const DEMO_DURATION_MINUTES = 15;
const SAMPLE_COUNT = 100;
const GRAVITON_COST_PER_HOUR = 0.0408; // c7g.2xlarge Spot
const GPU_COST_PER_HOUR = 0.50;        // g5g.2xlarge Spot
const ON_PREM_COST = 1800;
const STANDARD_CLOUD_COST = 120;

const OmicsDashboard = () => {
  // State variables
  const [timeElapsed, setTimeElapsed] = useState(0);
  const [jobStatus, setJobStatus] = useState({});
  const [resourceUtilization, setResourceUtilization] = useState([]);
  const [costAccrued, setCostAccrued] = useState(0);
  const [variantStats, setVariantStats] = useState(null);
  const [demoRunning, setDemoRunning] = useState(false);
  const [completedSamples, setCompletedSamples] = useState(0);
  const [activeTab, setActiveTab] = useState('progress');
  const [simulationMode, setSimulationMode] = useState(false);
  const [error, setError] = useState(null);
  
  // Initialize demo
  useEffect(() => {
    const initDemo = async () => {
      try {
        setJobStatus({
          status: 'INITIALIZING',
          message: 'Preparing resources...'
        });
        
        const config = await demoService.getConfig();
        
        // If we get valid config, we're not in simulation mode
        setSimulationMode(config.simulation || false);
        
        if (!config.simulation) {
          // Get initial job status
          const status = await demoService.getJobStatus();
          setJobStatus(status);
        }
      } catch (error) {
        console.error('Failed to initialize demo:', error);
        setError('Failed to connect to API server. Using simulation mode.');
        setSimulationMode(true);
        setJobStatus({
          status: 'READY',
          message: 'Demo ready (Simulation Mode)'
        });
      }
    };
    
    initDemo();
  }, []);

  // Start the demo
  const startDemo = async () => {
    try {
      setDemoRunning(true);
      setTimeElapsed(0);
      setCompletedSamples(0);
      setCostAccrued(0);
      setError(null);
      
      // Set initial job status
      setJobStatus({
        status: 'RUNNING',
        message: 'Processing samples...'
      });
      
      // Initialize resource utilization data
      setResourceUtilization([
        { time: 0, cpuCount: 0, cpuUtilization: 0, memoryUtilization: 0, gpuUtilization: 0 }
      ]);
      
      if (!simulationMode) {
        // Call API to start the demo
        await demoService.startDemo();
      }
    } catch (error) {
      console.error('Failed to start demo:', error);
      setError('Failed to start demo. Using simulation mode.');
      setSimulationMode(true);
    }
  };

  // Update demo progress every second
  useEffect(() => {
    if (!demoRunning) return;
    
    const interval = setInterval(async () => {
      setTimeElapsed(prev => {
        const newTime = prev + 1;
        
        if (simulationMode) {
          // Simulation logic
          // Update completed samples based on time
          if (newTime < DEMO_DURATION_MINUTES * 60 * 0.8) {
            setCompletedSamples(Math.min(
              SAMPLE_COUNT,
              Math.floor((newTime / (DEMO_DURATION_MINUTES * 60 * 0.7)) * SAMPLE_COUNT)
            ));
          } else {
            setCompletedSamples(SAMPLE_COUNT);
          }
          
          // Update cost based on resource usage
          const newCost = calculateCost(newTime);
          setCostAccrued(newCost);
          
          // Update resource utilization
          setResourceUtilization(prev => {
            const newData = [...prev];
            const timeMinutes = newTime / 60;
            const cpuCount = simulateCpuCount(timeMinutes);
            const cpuUtil = simulateUtilization(timeMinutes, 75, 95);
            const memUtil = simulateUtilization(timeMinutes, 60, 85);
            const gpuUtil = timeMinutes > 10 ? simulateUtilization(timeMinutes - 10, 80, 95) : 0;
            
            newData.push({
              time: timeMinutes,
              cpuCount,
              cpuUtilization: cpuUtil,
              memoryUtilization: memUtil,
              gpuUtilization: gpuUtil
            });
            
            // Keep only last 15 minutes of data
            return newData.slice(-15);
          });
          
          // End demo after specified duration
          if (newTime >= DEMO_DURATION_MINUTES * 60) {
            clearInterval(interval);
            setDemoRunning(false);
            setJobStatus({
              status: 'COMPLETED',
              message: 'Analysis completed successfully!'
            });
            
            // Set simulated variant stats
            setVariantStats({
              totalVariants: 243826,
              transitions: 167538,
              transversions: 76288,
              tiTvRatio: 2.196
            });
          }
        } else {
          // Non-simulation mode - fetch real data from API
          try {
            // Get job status
            const status = await demoService.getJobStatus();
            setJobStatus(status);
            
            // Get resource utilization
            const resources = await demoService.getResourceUtilization();
            if (resources.cpuCount) {
              setResourceUtilization(prev => {
                const newData = [...prev];
                newData.push({
                  time: timeMinutes,
                  ...resources
                });
                return newData.slice(-15);
              });
            }
            
            // Update samples completed
            setCompletedSamples(status.completedSamples || 0);
            
            // Update cost
            setCostAccrued(status.costAccrued || 0);
            
            // Check if demo has completed
            if (status.status === 'COMPLETED') {
              // Get variant stats
              const stats = await demoService.getVariantStats();
              setVariantStats(stats);
              
              // End the demo
              clearInterval(interval);
              setDemoRunning(false);
            }
          } catch (error) {
            console.error('Error fetching demo data:', error);
            setError('Error connecting to API. Switching to simulation mode.');
            setSimulationMode(true);
          }
        }
        
        return newTime;
      });
    }, 1000);
    
    return () => clearInterval(interval);
  }, [demoRunning, simulationMode]);

  // Calculate demo cost
  const calculateCost = (timeSeconds) => {
    const timeHours = timeSeconds / 3600;
    const cpuTimeHours = simulateCpuTimeHours(timeSeconds);
    const gpuTimeHours = simulateGpuTimeHours(timeSeconds);
    
    const computeCost = cpuTimeHours * GRAVITON_COST_PER_HOUR + gpuTimeHours * GPU_COST_PER_HOUR;
    const storageCost = 0.02 * (timeSeconds / (DEMO_DURATION_MINUTES * 60));
    const transferCost = 0.01 * (timeSeconds / (DEMO_DURATION_MINUTES * 60));
    
    return computeCost + storageCost + transferCost;
  };

  // Simulate CPU instance scaling pattern
  const simulateCpuCount = (timeMinutes) => {
    if (timeMinutes < 1) return Math.floor(timeMinutes * 20);
    if (timeMinutes < 3) return Math.floor(20 + (timeMinutes - 1) * 70);
    if (timeMinutes < 8) return 160;
    if (timeMinutes < 10) return Math.floor(160 - (timeMinutes - 8) * 60);
    return Math.floor(40 - (Math.min(timeMinutes, 13) - 10) * 10);
  };

  // Simulate CPU time accrual
  const simulateCpuTimeHours = (timeSeconds) => {
    const timeMinutes = timeSeconds / 60;
    let cpuHours = 0;
    
    // Calculate area under the CPU count curve
    for (let i = 0; i < timeMinutes; i++) {
      cpuHours += simulateCpuCount(i) / 60;
    }
    
    return cpuHours;
  };

  // Simulate GPU time accrual
  const simulateGpuTimeHours = (timeSeconds) => {
    const timeMinutes = timeSeconds / 60;
    
    // GPU only used in later part of demo
    if (timeMinutes < 10) return 0;
    
    // 4 GPUs for remainder of demo
    return 4 * (timeMinutes - 10) / 60;
  };

  // Simulate utilization metrics with some randomness
  const simulateUtilization = (timeMinutes, min, max) => {
    const baseUtil = min + Math.random() * (max - min);
    // Add some time-based variation
    return Math.min(100, baseUtil + Math.sin(timeMinutes) * 5);
  };

  // Format time as MM:SS
  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Format cost as USD
  const formatCost = (cost) => {
    return `$${cost.toFixed(2)}`;
  };

  // Progress component
  const ProgressTab = () => (
    <div className="mt-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="p-4 bg-white rounded shadow">
          <h3 className="text-lg font-semibold mb-2">Time Elapsed</h3>
          <div className="text-3xl font-bold">{formatTime(timeElapsed)} / {DEMO_DURATION_MINUTES}:00</div>
          <div className="h-2 w-full bg-gray-200 rounded mt-2">
            <div 
              className="h-2 bg-blue-500 rounded" 
              style={{ width: `${Math.min(100, (timeElapsed / (DEMO_DURATION_MINUTES * 60)) * 100)}%` }}
            ></div>
          </div>
        </div>
        
        <div className="p-4 bg-white rounded shadow">
          <h3 className="text-lg font-semibold mb-2">Cost Accrued</h3>
          <div className="text-3xl font-bold">{formatCost(costAccrued)}</div>
          <div className="mt-2 text-sm text-gray-500">Estimated total: {formatCost(38)}</div>
        </div>
      </div>
      
      <div className="mt-4 p-4 bg-white rounded shadow">
        <h3 className="text-lg font-semibold mb-2">Sample Processing</h3>
        <div className="flex justify-between mb-1">
          <span>{completedSamples} of {SAMPLE_COUNT} samples</span>
          <span>{Math.floor((completedSamples / SAMPLE_COUNT) * 100)}%</span>
        </div>
        <div className="h-4 w-full bg-gray-200 rounded">
          <div 
            className="h-4 bg-green-500 rounded" 
            style={{ width: `${(completedSamples / SAMPLE_COUNT) * 100}%` }}
          ></div>
        </div>
      </div>
      
      <div className="mt-4 p-4 bg-white rounded shadow">
        <h3 className="text-lg font-semibold mb-4">Resource Utilization</h3>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={resourceUtilization}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="time" label={{ value: 'Time (minutes)', position: 'insideBottom', offset: -5 }} />
            <YAxis yAxisId="left" label={{ value: 'CPU Count', angle: -90, position: 'insideLeft' }} />
            <YAxis yAxisId="right" orientation="right" label={{ value: 'Utilization %', angle: -90, position: 'insideRight' }} />
            <Tooltip />
            <Legend />
            <Line yAxisId="left" type="monotone" dataKey="cpuCount" stroke="#8884d8" name="CPU Count" />
            <Line yAxisId="right" type="monotone" dataKey="cpuUtilization" stroke="#82ca9d" name="CPU Utilization %" />
            <Line yAxisId="right" type="monotone" dataKey="memoryUtilization" stroke="#ffc658" name="Memory Utilization %" />
            <Line yAxisId="right" type="monotone" dataKey="gpuUtilization" stroke="#ff8042" name="GPU Utilization %" />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );

  // Cost analysis component
  const CostTab = () => {
    const costData = [
      { name: 'CPU (Graviton)', value: costAccrued * 0.65 },
      { name: 'GPU', value: costAccrued * 0.25 },
      { name: 'Storage', value: costAccrued * 0.07 },
      { name: 'Data Transfer', value: costAccrued * 0.03 }
    ];
    
    const costComparisonData = [
      { name: 'On-Premises', value: ON_PREM_COST },
      { name: 'Standard Cloud', value: STANDARD_CLOUD_COST },
      { name: 'Optimized Cloud', value: costAccrued }
    ];
    
    const savingsPercentage = ((ON_PREM_COST - costAccrued) / ON_PREM_COST * 100).toFixed(1);
    
    const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042'];
    
    return (
      <div className="mt-4">
        <div className="p-4 bg-white rounded shadow">
          <h3 className="text-lg font-semibold mb-2">Cost Breakdown</h3>
          <div className="grid grid-cols-2 gap-4">
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={costData}
                  cx="50%"
                  cy="50%"
                  labelLine={true}
                  outerRadius={100}
                  fill="#8884d8"
                  dataKey="value"
                  label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                >
                  {costData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => formatCost(value)} />
              </PieChart>
            </ResponsiveContainer>
            
            <div className="flex flex-col justify-center">
              <div className="mb-4">
                <h4 className="font-semibold">Total Cost</h4>
                <div className="text-3xl font-bold">{formatCost(costAccrued)}</div>
              </div>
              
              <div>
                <h4 className="font-semibold">Savings vs. On-Premises</h4>
                <div className="text-3xl font-bold">{savingsPercentage}%</div>
                <div className="text-sm text-gray-500">({formatCost(ON_PREM_COST - costAccrued)})</div>
              </div>
            </div>
          </div>
        </div>
        
        <div className="mt-4 p-4 bg-white rounded shadow">
          <h3 className="text-lg font-semibold mb-4">Cost Comparison</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={costComparisonData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis tickFormatter={(value) => formatCost(value)} />
              <Tooltip formatter={(value) => formatCost(value)} />
              <Bar dataKey="value" fill="#8884d8" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    );
  };

  // Results component
  const ResultsTab = () => (
    <div className="mt-4">
      <div className="p-4 bg-white rounded shadow">
        <h3 className="text-lg font-semibold mb-4">Analysis Results</h3>
        
        {variantStats ? (
          <>
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="p-3 bg-gray-100 rounded">
                <div className="text-sm text-gray-500">Total Variants</div>
                <div className="text-2xl font-bold">{variantStats.totalVariants.toLocaleString()}</div>
              </div>
              
              <div className="p-3 bg-gray-100 rounded">
                <div className="text-sm text-gray-500">Ti/Tv Ratio</div>
                <div className="text-2xl font-bold">{variantStats.tiTvRatio}</div>
              </div>
            </div>
            
            <div className="mt-6">
              <h4 className="font-semibold mb-2">Transition/Transversion Distribution</h4>
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie
                    data={[
                      { name: 'Transitions', value: variantStats.transitions },
                      { name: 'Transversions', value: variantStats.transversions }
                    ]}
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(1)}%`}
                  >
                    <Cell fill="#0088FE" />
                    <Cell fill="#00C49F" />
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </>
        ) : (
          <div className="text-center py-10">
            <div className="text-gray-500">Analysis in progress...</div>
          </div>
        )}
      </div>
      
      <div className="mt-4 p-4 bg-white rounded shadow">
        <h3 className="text-lg font-semibold mb-4">Performance Summary</h3>
        
        <div className="grid grid-cols-2 gap-4">
          <div>
            <h4 className="font-semibold mb-2">Time Comparison</h4>
            <div className="flex items-center justify-between p-3 bg-gray-100 rounded mb-2">
              <span>On-Premises</span>
              <span className="font-bold">2 weeks</span>
            </div>
            <div className="flex items-center justify-between p-3 bg-gray-100 rounded">
              <span>AWS Cloud</span>
              <span className="font-bold">{formatTime(timeElapsed)}</span>
            </div>
          </div>
          
          <div>
            <h4 className="font-semibold mb-2">Resource Utilization</h4>
            <div className="flex items-center justify-between p-3 bg-gray-100 rounded mb-2">
              <span>Peak vCPUs</span>
              <span className="font-bold">160</span>
            </div>
            <div className="flex items-center justify-between p-3 bg-gray-100 rounded">
              <span>GPUs Used</span>
              <span className="font-bold">4</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="container mx-auto p-4">
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4">
          <span className="block sm:inline">{error}</span>
        </div>
      )}
      
      {simulationMode && (
        <div className="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded relative mb-4">
          <span className="block sm:inline">
            Running in simulation mode. No live data from AWS.
          </span>
        </div>
      )}
      
      <div className="bg-white rounded shadow p-4 mb-4">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-bold">AWS Omics Demo Dashboard</h2>
          
          <div className="flex items-center">
            <div className={`mr-4 px-3 py-1 rounded-full ${
              jobStatus.status === 'COMPLETED' ? 'bg-green-100 text-green-800' :
              jobStatus.status === 'RUNNING' ? 'bg-blue-100 text-blue-800' :
              'bg-yellow-100 text-yellow-800'
            }`}>
              {jobStatus.status}
            </div>
            
            {!demoRunning && jobStatus.status !== 'COMPLETED' && (
              <button
                onClick={startDemo}
                className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
              >
                Start Demo
              </button>
            )}
          </div>
        </div>
        
        {jobStatus.message && (
          <div className="mt-2 text-sm text-gray-500">{jobStatus.message}</div>
        )}
      </div>
      
      <div className="bg-white rounded shadow overflow-hidden">
        <div className="flex border-b">
          <button
            className={`px-4 py-2 ${activeTab === 'progress' ? 'bg-blue-500 text-white' : 'bg-gray-100'}`}
            onClick={() => setActiveTab('progress')}
          >
            Progress
          </button>
          <button
            className={`px-4 py-2 ${activeTab === 'cost' ? 'bg-blue-500 text-white' : 'bg-gray-100'}`}
            onClick={() => setActiveTab('cost')}
          >
            Cost Analysis
          </button>
          <button
            className={`px-4 py-2 ${activeTab === 'results' ? 'bg-blue-500 text-white' : 'bg-gray-100'}`}
            onClick={() => setActiveTab('results')}
          >
            Results
          </button>
        </div>
        
        <div className="p-4">
          {activeTab === 'progress' && <ProgressTab />}
          {activeTab === 'cost' && <CostTab />}
          {activeTab === 'results' && <ResultsTab />}
        </div>
      </div>
    </div>
  );
};

export default OmicsDashboard;