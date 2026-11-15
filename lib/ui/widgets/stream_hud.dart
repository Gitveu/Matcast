import 'package:flutter/material.dart';
import '../../models/stream_stats.dart';

class StreamHud extends StatelessWidget {
  final StreamStats stats;
  final String deviceName;
  final Duration? streamDuration;
  final VoidCallback? onClose;

  const StreamHud({
    super.key,
    required this.stats,
    required this.deviceName,
    this.streamDuration,
    this.onClose,
  });

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deviceName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          _divider(),
          const SizedBox(width: 12),
          _metric('RES', stats.resolution),
          const SizedBox(width: 10),
          _divider(),
          const SizedBox(width: 10),
          _metric('FPS', stats.fps.toStringAsFixed(0)),
          const SizedBox(width: 10),
          _divider(),
          const SizedBox(width: 10),
          _metric('BITRATE', '${stats.bitrateMbps.toStringAsFixed(1)} Mbps'),
          const SizedBox(width: 10),
          _divider(),
          const SizedBox(width: 10),
          _metric('LATENCY', '~${stats.latencyMs} ms'),
          if (streamDuration != null) ...[
            const SizedBox(width: 10),
            _divider(),
            const SizedBox(width: 10),
            _metric('TIME', _formatDuration(streamDuration!)),
          ],
          if (onClose != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 14,
      color: Colors.white24,
    );
  }

  Widget _metric(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
