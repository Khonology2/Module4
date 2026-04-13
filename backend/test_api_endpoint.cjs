const http = require('http');

async function testApiEndpoint() {
  const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/api/v1/deliverables/11d458da-6356-47c2-89ed-8b9cc5c5d109/updateStatus',
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMzU2YTFiLTZlMDgtNDRiOC04NDk5LWE0NDkxZDE0ZTk4OCIsImVtYWlsIjoiZGhsYW1pbmluYW9taTFAZ21haWwuY29tIiwicm9sZSI6ImRlbGl2ZXJ5TGVhZCIsImlhdCI6MTc3MzkyMjEwNSwiZXhwIjoxNzc0MDA4NTA1fQ.eaGOVsEAWyWw30rMxC1U4gsYHwnRTQrhFI-xGS0jnzU'
    }
  };

  const data = JSON.stringify({ status: 'signed_off' });

  const req = http.request(options, (res) => {
    let responseData = '';

    res.on('data', (chunk) => {
      responseData += chunk;
    });

    res.on('end', () => {
      console.log('🌐 API Response Status:', res.statusCode);
      console.log('📦 Response Body:', responseData);
      
      try {
        const parsed = JSON.parse(responseData);
        if (parsed.success) {
          console.log('✅ API endpoint working correctly!');
          console.log('📊 Updated deliverable:', JSON.stringify(parsed.data, null, 2));
        } else {
          console.log('❌ API returned error:', parsed.error);
        }
      } catch (e) {
        console.log('❌ Failed to parse response:', e.message);
      }
    });
  });

  req.on('error', (error) => {
    console.error('❌ Request error:', error.message);
  });

  req.write(data);
  req.end();
}

testApiEndpoint();
