let webpack = require('./webpack.config.js');

// Karma configuration
// Generated on Sun Dec 23 2018 14:55:20 GMT+1100 (Australian Eastern Daylight Time)

module.exports = function(config) {
  config.set({
    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '',

    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['jasmine', 'jasmine-matchers'],

    // list of files / patterns to load in the browser
    files: ['src/tests.webpack.js'],

    // list of files / patterns to exclude
    exclude: [],

    webpack,

    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      'src/tests.webpack.js': ['webpack', 'sourcemap'],
      'src/**/*.js': ['eslint', 'webpack', 'sourcemap'],
    },
    logLevel: config.LOG_INFO,

    // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['mocha'],

    // web server port
    port: 9876,

    // enable / disable colors in the output (reporters and logs)
    colors: true,

    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,

    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ['ChromiumHeadlessRoot'],

    customLaunchers: {
      ChromiumHeadlessRoot: {
        base: 'ChromiumHeadless',
        flags: ['--no-sandbox'],
      },
    },

    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    singleRun: true,

    // Concurrency level
    // how many browser should be started simultaneous
    concurrency: Infinity,

    webpackMiddleware: {
      noInfo: true,
      stats: 'errors-only',
    },
    mochaReporter: {
      output: 'autowatch',
    },
  });
};
