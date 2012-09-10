GenePool Changelog
=====================

1.3.0 / 2012-09-10

  - Allow :timeout option to raise Timeout::Error if waiting for a connection exceeds this value.

1.2.4 / 2012-09-05

  - require 'thread' under ruby 1.8 so that mutex is defined (Thanks soupmatt!)

1.2.3 / 2012-02-23

  - Allow setting of options[:close_proc] to nil

1.2.2 / 2012-02-23

  - Do a respond_to? to check compatibility instead of hacking around with $VERBOSE

1.2.1 / 2012-02-23

  - Oops, broke 1.8 compatibility with 1.2.0.  Hacking $VERBOSE setting so as to not spam deprecation warnings.

1.2.0 / 2012-02-23

  - Allow dynamic modification of pool size.
  - Added close method which will prevent checking out of new connections and wait for and close all current connections.
  - Added remove_idle method which will close all current connections which have been idle for the given idle_time.
  - with_connection_auto_retry no longer accepts an argument (it defaulted to true previously) because of the addition
    of the close_proc option which defaults to :close.  This should be set to nil if no closing is necessary
    (Deepest apologies for making an incompatible change if anyone is actually using this argument).

1.1.1 / 2010-11-18

  - In with_connection_auto_retry, add check for e.message =~ /expired/ as JRuby exception won't be a
    Timeout::Error at this point (http://jira.codehaus.org/browse/JRUBY-5194)

1.1.0 / 2010-11-11

  - Added with_connection_auto_retry to automatically retry yield block if a non-timeout exception occurs

1.0.1 / 2010-09-12

  - Debug logging was NOT thread-safe

1.0.0 / 2010-09-05

  - Initial release
