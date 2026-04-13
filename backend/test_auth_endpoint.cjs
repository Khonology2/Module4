const http = require('http');

async function testAuthentication() {
  console.log('🧪 Testing authentication on signature endpoint...');
  
  const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/api/v1/sign-off-reports/6b092421-a0d4-47df-aeb6-d672cc82875f/signatures',
    method: 'GET', // Test GET endpoint first
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMzU2YTFiLTZlMDgtNDRiOC04NDk5LWE0NDkxZDE0ZTk4OCIsImVtYWlsIjoiZGhsYW1pbmluYW9taTFAZ21haWwuY29tIiwicm9sZSI6ImRlbGl2ZXJ5TGVhZCIsImlhdCI6MTc3NDI0OTQxMSwiZXhwIjoxNzc0MzM1ODExfQ.T_AjRYWdLAnQ9qZS72HwVSfZrtd91fKCo8-xCpfxO4Q'
    }
  };

  const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      console.log('🌐 GET Response Status:', res.statusCode);
      console.log('📦 GET Response Body:', data);
      
      if (res.statusCode === 200) {
        console.log('✅ Authentication works for GET request');
      } else {
        console.log('❌ Authentication failed for GET request');
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.end();
}

testAuthentication();
