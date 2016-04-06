/**
 * New Relic agent configuration.
 *
 * See lib/config.defaults.js in the agent distribution for a more complete
 * description of configuration variables and their potential values.
 */
exports.config = {
  /**
   * Array of application names.
   */
  app_name : [process.env.NEW_RELIC_APP_NAME],
  /**
   * Your New Relic license key.
   */
  license_key : process.env.NEW_RELIC_LICENSE_KEY,
  /**
   * Whether to capture parameters in the request URL in slow transaction
   * traces and error traces. Because this can pass sensitive data, it's
   * disabled by default. If there are specific parameters you want ignored,
   * use ignored_params.
   *
   * @env NEW_RELIC_CAPTURE_PARAMS
   */
  capture_params : true,
  logging : {
    /**
     * Level at which to log. 'trace' is most useful to New Relic when diagnosing
     * issues with the agent, 'info' and higher will impose the least overhead on
     * production applications.
     */
    level : 'info',
    /**
     * Where to put the log file -- by default just uses process.cwd +
     * 'newrelic_agent.log'. A special case is a filepath of 'stdout',
     * in which case all logging will go to stdout, or 'stderr', in which
     * case all logging will go to stderr.
     *
     * @env NEW_RELIC_LOG
     */
    filepath : 'stdout'
  },
  /**
   * Array of parameters you don't want captured off request URLs in slow
   * transaction traces and error traces.
   *
   * @env NEW_RELIC_IGNORED_PARAMS
   */
  ignored_params : ["token"],
  error_collector : {
    /**
     * List of HTTP error status codes the error tracer should disregard.
     * Ignoring a status code means that the transaction is not renamed to
     * match the code, and the request is not treated as an error by the error
     * collector.
     *
     * Defaults to 404 NOT FOUND.
     *
     * @env NEW_RELIC_ERROR_COLLECTOR_IGNORE_ERROR_CODES
     */
    ignore_status_codes : [404, 403, 400, 409]
  },
  rules : {
    /**
     * A list of patterns for matching incoming request URLs to be ignored by
     * the agent. Patterns may be strings or regular expressions.
     *
     * @env NEW_RELIC_IGNORING_RULES
     */
    ignore : ['^/rtupdates']
  }
};
