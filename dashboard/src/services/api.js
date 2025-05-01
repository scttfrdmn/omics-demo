import axios from 'axios';

// Create axios instance with base settings
const api = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add error handling interceptor
api.interceptors.response.use(
  response => response,
  error => {
    console.error('API Error:', error);
    // You can add global error handling logic here
    return Promise.reject(error);
  }
);

// API service functions
export const demoService = {
  // Get demo configuration
  getConfig: async () => {
    try {
      const response = await api.get('/config');
      return response.data;
    } catch (error) {
      console.error('Failed to get demo configuration:', error);
      throw error;
    }
  },

  // Get job status
  getJobStatus: async () => {
    try {
      const response = await api.get('/status');
      return response.data;
    } catch (error) {
      console.error('Failed to get job status:', error);
      throw error;
    }
  },

  // Get resource utilization
  getResourceUtilization: async () => {
    try {
      const response = await api.get('/resources');
      return response.data;
    } catch (error) {
      console.error('Failed to get resource utilization:', error);
      throw error;
    }
  },

  // Get variant stats
  getVariantStats: async () => {
    try {
      const response = await api.get('/stats');
      return response.data;
    } catch (error) {
      console.error('Failed to get variant statistics:', error);
      throw error;
    }
  },

  // Start the demo
  startDemo: async () => {
    try {
      const response = await api.post('/start');
      return response.data;
    } catch (error) {
      console.error('Failed to start demo:', error);
      throw error;
    }
  },

  // Fallback to simulation mode when API is unavailable
  useFallbackMode: async () => {
    return {
      simulation: true,
      message: 'Using simulation mode - API not available'
    };
  }
};

export default api;