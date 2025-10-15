const { backoffDelay } = require('../src/app');

describe('backoffDelay unit test', () => {

  it('should return the base delay for the first attempt (i=0)', () => {
    // GIVEN the first retry attempt (index 0).
    const attempt = 0;

    // WHEN the delay is calculated.
    const delay = backoffDelay(attempt);

    // THEN the result should be the base delay of 500ms.
    expect(delay).toBe(500);
  });

  it('should return an exponentially increased delay for subsequent attempts', () => {
    // GIVEN a subsequent retry attempt (e.g., the 4th attempt, index 3).
    const attempt = 3;

    // WHEN the delay is calculated.
    const delay = backoffDelay(attempt);

    // THEN the result should be exponentially larger (500 * 2^3 = 4000).
    expect(delay).toBe(4000);
  });

  it('should not exceed the maximum delay of 30000ms', () => {
    // GIVEN a high retry attempt that would exceed the cap (index 10).
    const attempt = 10;

    // WHEN the delay is calculated.
    const delay = backoffDelay(attempt);

    // THEN the result should be capped at the maximum of 30000ms.
    expect(delay).toBe(30000);
  });
});