module.exports = {
    setupFilesAfterEnv: ['./jest.setup.js'],
    collectCoverageFrom: [
      'src/**/*.js',
    ],
    // Specify the directory where Jest should output its coverage files
    coverageDirectory: 'coverage',
    coverageProvider: 'v8',
  };