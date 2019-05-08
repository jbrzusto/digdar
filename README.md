# digdar #
fork of red pitaya dedicated to digitizing pulsed marine radar

## Issues ##

FPGA:
- spurious detection of ARP pulse sometimes splits a single sweep into two.
  If a trigger_gen object is purely for counting trigger pulses, rather than initiating
  action on them (as is the case for ACP, ARP), then we should allow for the
  "delay" parameter to be used as a confirmation period, rather than a delay.
  i.e. while in `STATE_DELAYING`, the trigger_gen object can fall back into
  `STATE_WAITING_EXCITE` if the signal level falls back below the excite threshold.
  It would be nice to record the clock at the start of the delay period, though.

Test: (i.e. app, but in Test folder)
- Test/digdar is sometimes dropping a significant number of pulses from a sweep;
  likely, there is a problem with the reader/writer shared access to the pulse
  buffer.  The chunking scheme was intended to allow data to be offloaded with
  minimal latency, so that a sweep could be transmitted a small portion at a time.
  This is fine, but we should allocate sweep-based buffers for filling by the
  writer, and offloading by the reader.  We don't want the writer to ever
  have to wait long to have a place to write data to.
