// Test script for HealthHub authentication flow
const axios = require('axios');

const BASE_URL = 'http://localhost:3001/api';

// Test data
const testUser = {
  appleUserId: 'test_apple_' + Date.now(),
  email: 'test@healthhub.com',
  receiptData: 'fake_receipt_data_for_testing'
};

let authToken = null;

async function runTests() {
  console.log('🧪 Starting HealthHub Authentication Tests\n');

  try {
    // Test 1: Health check
    await testHealthCheck();
    
    // Test 2: Apple authentication
    await testAppleAuth();
    
    // Test 3: Subscription status
    await testSubscriptionStatus();
    
    // Test 4: Invalid token
    await testInvalidToken();
    
    console.log('\n✅ All tests completed successfully!');
    process.exit(0);
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    process.exit(1);
  }
}

async function testHealthCheck() {
  console.log('1. Testing health check...');
  
  try {
    const response = await axios.get(`${BASE_URL.replace('/api', '')}/health`);
    
    if (response.status === 200 && response.data.status === 'healthy') {
      console.log('   ✅ Server is healthy');
    } else {
      throw new Error('Health check failed');
    }
  } catch (error) {
    throw new Error(`Health check failed: ${error.message}`);
  }
}

async function testAppleAuth() {
  console.log('2. Testing Apple authentication...');
  
  try {
    const response = await axios.post(`${BASE_URL}/auth/apple`, testUser);
    
    if (response.data.success && response.data.token) {
      authToken = response.data.token;
      console.log('   ✅ Authentication successful');
      console.log(`   📝 Token: ${authToken.substring(0, 20)}...`);
      console.log(`   👤 User ID: ${response.data.user.id}`);
    } else {
      throw new Error('Authentication response invalid');
    }
  } catch (error) {
    throw new Error(`Apple auth failed: ${error.message}`);
  }
}

async function testSubscriptionStatus() {
  console.log('3. Testing subscription status...');
  
  if (!authToken) {
    throw new Error('No auth token available');
  }
  
  try {
    const response = await axios.get(`${BASE_URL}/subscription/status`, {
      headers: {
        'Authorization': `Bearer ${authToken}`
      }
    });
    
    if (response.data.hasOwnProperty('isActive')) {
      console.log(`   ✅ Subscription status: ${response.data.isActive ? 'Active' : 'Inactive'}`);
      if (response.data.subscription) {
        console.log(`   📅 Expires: ${response.data.subscription.expiresAt || 'N/A'}`);
      }
    } else {
      throw new Error('Invalid subscription status response');
    }
  } catch (error) {
    throw new Error(`Subscription status failed: ${error.message}`);
  }
}

async function testInvalidToken() {
  console.log('4. Testing invalid token handling...');
  
  try {
    const response = await axios.get(`${BASE_URL}/subscription/status`, {
      headers: {
        'Authorization': 'Bearer invalid_token_here'
      }
    });
    
    // Should not reach here
    throw new Error('Invalid token was accepted');
    
  } catch (error) {
    if (error.response && error.response.status === 401) {
      console.log('   ✅ Invalid token properly rejected');
    } else {
      throw new Error(`Unexpected error: ${error.message}`);
    }
  }
}

// Manual testing instructions
function printManualTests() {
  console.log('\n📋 Manual Testing Checklist:');
  console.log('');
  console.log('iOS App Testing:');
  console.log('1. ☐ Complete a subscription purchase');
  console.log('2. ☐ Sign in with Apple after purchase');
  console.log('3. ☐ Verify premium content unlocked in app');
  console.log('4. ☐ Check CloudKit sync works');
  console.log('');
  console.log('Web App Testing:');
  console.log('1. ☐ Load webapp in browser');
  console.log('2. ☐ Click "Sign in with Apple" button');
  console.log('3. ☐ Complete Apple authorization');
  console.log('4. ☐ Verify subscription status shows');
  console.log('5. ☐ Check premium content visibility');
  console.log('6. ☐ Test logout functionality');
  console.log('');
  console.log('Cross-Platform Testing:');
  console.log('1. ☐ Subscribe on iOS, verify web access');
  console.log('2. ☐ Sign out on web, verify login works');
  console.log('3. ☐ Test subscription expiration');
  console.log('4. ☐ Verify error handling');
}

// Database verification
async function verifyDatabase() {
  console.log('\n🗄️  Database Verification:');
  
  try {
    const sqlite3 = require('sqlite3').verbose();
    const db = new sqlite3.Database('healthhub.db');
    
    // Check users table
    db.get('SELECT COUNT(*) as count FROM users', (err, row) => {
      if (!err) {
        console.log(`   Users in database: ${row.count}`);
      }
    });
    
    // Check subscriptions table
    db.get('SELECT COUNT(*) as count FROM subscriptions', (err, row) => {
      if (!err) {
        console.log(`   Subscriptions in database: ${row.count}`);
      }
    });
    
    db.close();
  } catch (error) {
    console.log('   ⚠️  Database verification skipped (sqlite3 not available)');
  }
}

// Performance test
async function performanceTest() {
  console.log('\n⚡ Performance Test:');
  
  const start = Date.now();
  
  // Test multiple concurrent requests
  const promises = [];
  for (let i = 0; i < 10; i++) {
    promises.push(axios.get(`${BASE_URL.replace('/api', '')}/health`));
  }
  
  try {
    await Promise.all(promises);
    const duration = Date.now() - start;
    console.log(`   ✅ 10 concurrent requests completed in ${duration}ms`);
    
    if (duration > 5000) {
      console.log('   ⚠️  Performance may be slow for production');
    }
  } catch (error) {
    console.log('   ❌ Performance test failed');
  }
}

// Main execution
if (require.main === module) {
  console.log('🚀 HealthHub Authentication System Test Suite\n');
  
  // Run automated tests
  runTests()
    .then(() => {
      // Additional verification
      verifyDatabase();
      performanceTest();
      printManualTests();
    })
    .catch((error) => {
      console.error('Test suite failed:', error);
      process.exit(1);
    });
}

module.exports = {
  runTests,
  testHealthCheck,
  testAppleAuth,
  testSubscriptionStatus
};