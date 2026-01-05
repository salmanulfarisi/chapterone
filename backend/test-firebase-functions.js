/**
 * Test script to verify Firebase Functions configuration
 * Run with: node test-firebase-functions.js
 */

require('dotenv').config();
const firebaseFunctionsService = require('./services/firebaseFunctions');

console.log('=== Firebase Functions Configuration Test ===\n');

const config = firebaseFunctionsService.getConfig();
console.log('Configuration:');
console.log(JSON.stringify(config, null, 2));

console.log('\n=== Testing Function Call ===\n');
console.log('Note: This test will fail with "invalid FCM token" error because we use a test token.');
console.log('This is EXPECTED and confirms the function is working correctly.\n');

// Test with a simple call (will fail with invalid token, but confirms function is accessible)
firebaseFunctionsService.callFunction('sendNotification', {
  userId: 'test',
  token: 'test-token',
  title: 'Test',
  body: 'Test message',
})
  .then((result) => {
    console.log('Result:', JSON.stringify(result, null, 2));
    if (!result.success) {
      if (result.details?.message?.includes('not a valid FCM registration token')) {
        console.log('\n✅ Function is working correctly!');
        console.log('The error is expected - we used a test token. Real FCM tokens will work.');
      } else {
        console.error('\n❌ Function call failed!');
        console.error('Error:', result.error);
        if (result.details) {
          console.error('Details:', JSON.stringify(result.details, null, 2));
        }
      }
    } else {
      console.log('\n✅ Function call successful!');
    }
  })
  .catch((error) => {
    console.error('Exception:', error);
  });

