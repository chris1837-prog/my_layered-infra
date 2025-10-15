const request = require('supertest');
const { exec } = require('child_process');

const appUrl = 'http://localhost:3000';

/**
 * A helper function to run shell commands from our test.
 * @param {string} command The shell command to execute.
 * @returns {Promise<string>} The stdout of the command.
 */
function runCommand(command) {
  const composeCommand = `docker compose -f ../docker-compose.yml ${command}`;
  return new Promise((resolve, reject) => {
    exec(composeCommand, (error, stdout, stderr) => {
      if (error) {
        console.error(`Error executing: ${composeCommand}\n${stderr}`);
        return reject(error);
      }
      resolve(stdout);
    });
  });
}

describe('Application Resilience', () => {
  jest.setTimeout(60000);

  afterAll(async () => {
    console.log('Ensuring postgres container is running after resilience tests...');
    await runCommand('start postgres');
  });

  it('should return 503 when the database is down and recover to 200', async () => {
    // GIVEN the application is running and healthy
    console.log('GIVEN: Verifying initial healthy state...');
    let response = await request(appUrl).get('/health');
    expect(response.statusCode).toBe(200);
    console.log('App is initially healthy.');

    // WHEN the database connection is lost
    console.log('WHEN: Simulating database failure...');
    await runCommand('stop postgres');
    await new Promise(res => setTimeout(res, 5000));
    console.log('Postgres container stopped.');

    // THEN the application should report an unhealthy status
    console.log('THEN: Checking for 503 unhealthy status...');
    response = await request(appUrl).get('/health');
    expect(response.statusCode).toBe(503);
    console.log('App correctly reported 503 status.');

    // AND WHEN the database connection is restored
    console.log('AND WHEN: Simulating database recovery...');
    await runCommand('start postgres');
    console.log('Postgres container started.');

    // THEN the application should recover and report a healthy status
    console.log('THEN: Waiting for app to recover...');
    let recovered = false;
    for (let i = 0; i < 15; i++) {
      try {
        response = await request(appUrl).get('/health');
        if (response.statusCode === 200) {
          recovered = true;
          break;
        }
      } catch (error) {
        // Ignore network errors
      }
      await new Promise(res => setTimeout(res, 2000));
    }

    expect(recovered).toBe(true);
    console.log('App successfully recovered to 200.');
  });
});