# CPU GPU Memory Disk Network

CPU load comes from host CPU counters and per-processor load info. Apple Silicon performance and efficiency core utilization uses logical-core grouping from sysctl when available.

GPU temperature is SMC-backed and depends on chip-specific keys. The app probes several known keys and falls back when a sensor is unavailable. GPU utilization is not the same as GPU temperature and should not be implied unless a real utilization source exists.

Memory stats come from VM statistics: used, wired, compressed, free, page-ins, page-outs, swap, and derived pressure. UI should explain pressure and swap in user terms, not only percentages.

Disk stats are gated because filesystem capacity and process-level disk activity do not need the same cadence as CPU load. Network throughput uses byte deltas over time, not a raw absolute counter.
