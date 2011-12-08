GenePool Changelog
=====================

1.2.0 / 2011-12-07

  - Allow dynamic modification of pool size.
  - Added close method which will prevent checking out of new connections and wait for and close all current connections.
  - Added remove_idle method which will close all current connections which have been idle for the given idle_time.

1.1.1 / 2010-11-18

  - In with_connection_auto_retry, add check for e.message =~ /expired/ as JRuby exception won't be a
    Timeout::Error at this point (http://jira.codehaus.org/browse/JRUBY-5194)

1.1.0 / 2010-11-11

  - Added with_connection_auto_retry to automatically retry yield block if a non-timeout exception occurs

1.0.1 / 2010-09-12

  - Debug logging was NOT thread-safe

1.0.0 / 2010-09-05

  - Initial release
