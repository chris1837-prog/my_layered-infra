const request = require('supertest');

// The base URL of our running application
const appUrl = 'http://localhost:3000';

// 'describe' creates a test suite, a collection of related tests.
describe('Health Endpoint (/health)', () => {

  // 'it' or 'test' defines a single test case.
  it('should return a 200 OK status and a correct JSON body', async () => {
    // Act: Make a GET request to the /health endpoint.
    const response = await request(appUrl).get('/health');

    // Assert: Check if the response is what we expect.
    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
});