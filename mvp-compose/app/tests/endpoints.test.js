const request = require('supertest');

const appUrl = 'http://localhost:3000';

describe('API Endpoints', () => {

  // Test for the root endpoint
  describe('GET /', () => {
    it('should return a 200 OK status and the text "ok"', async () => {
      // GIVEN a client wanting to check the root endpoint
      // WHEN a GET request is made to /
      const response = await request(appUrl).get('/');

      // THEN the response should have a 200 status code
      expect(response.statusCode).toBe(200);
      // AND the response body should be the text "ok"
      expect(response.text).toBe('ok');
    });
  });

  // Test for the liveness endpoint
  describe('GET /healthz', () => {
    it('should return a 200 OK status and a JSON body with { ok: true }', async () => {
      // GIVEN a client wanting to check the application's liveness
      // WHEN a GET request is made to /healthz
      const response = await request(appUrl).get('/healthz');

      // THEN the response should have a 200 status code
      expect(response.statusCode).toBe(200);
      // AND the response body should be a JSON object { ok: true }
      expect(response.body).toEqual({ ok: true });
    });
  });

  // Test for the main health/readiness endpoint
  describe('GET /health', () => {
    it('should return a 200 OK status and a correct JSON body', async () => {
      // GIVEN a client wanting to check the application's readiness (including DB)
      // WHEN a GET request is made to /health
      const response = await request(appUrl).get('/health');

      // THEN the response should have a 200 status code
      expect(response.statusCode).toBe(200);
      // AND the response body should be a JSON object { status: 'ok' }
      expect(response.body).toEqual({ status: 'ok' });
    });
  });

  // Test for a non-existent route (negative test case)
  describe('GET /nonexistent', () => {
    it('should return a 404 Not Found status', async () => {
      // GIVEN a client requesting a route that does not exist
      // WHEN a GET request is made to a nonexistent route
      const response = await request(appUrl).get('/a-route-that-does-not-exist');

      // THEN the response should have a 404 status code
      expect(response.statusCode).toBe(404);
    });
  });

});