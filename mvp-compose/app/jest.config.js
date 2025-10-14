module.exports = {
    // Tell Jest to collect coverage information from all .js files
    // inside the src directory
    collectCoverageFrom: [
      'src/**/*.js',
    ],
    // Specify the directory where Jest should output its coverage files
    coverageDirectory: 'coverage',
    coverageProvider: 'v8',
  };