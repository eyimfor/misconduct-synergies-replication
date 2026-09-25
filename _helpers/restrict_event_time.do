********************************************************************************
* Event-time restrictions around the merger: presence in event years -3 to -1,
* observations both before and after the merger, and event years -3 to +3. Each line
* runs under capture, so it applies only when its variables exist in the data in memory.
********************************************************************************

* Apply each event-time restriction whose variables exist
    cap keep if event_timelb <=-1 & event_timeub >=-3
    cap keep if min_event <=-1 & max_event >=0
    cap keep if event_time >=-3 & event_time <=3
