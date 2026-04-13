const http = require('http');

async function testUserAuth() {
  console.log('🧪 Testing user authentication...');
  
  const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/api/v1/auth/me',
    method: 'GET',
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
      console.log('🌐 Auth Response Status:', res.statusCode);
      console.log('📦 Auth Response Body:', data);
      
      if (res.statusCode === 200) {
        const userData = JSON.parse(data);
        console.log('✅ User authenticated successfully');
        console.log('👤 User ID:', userData.id);
        console.log('👤 User Role:', userData.role);
        console.log('👤 User Email:', userData.email);
      } else {
        console.log('❌ Authentication failed');
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.end();
}

testUserAuth();
