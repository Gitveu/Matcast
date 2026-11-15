import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../models/receiver_state.dart';
import '../../state/receiver_provider.dart';
import '../widgets/m3_stat_card.dart';
import '../widgets/stream_hud.dart';

class DisplayView extends StatefulWidget {
  const DisplayView({super.key});

  @override
  State<DisplayView> createState() => _DisplayViewState();
}

class _DisplayViewState extends State<DisplayView> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiverProvider>();
    final state = provider.state;
    final isStreaming = state.status == ReceiverStatus.streaming;

    return Scaffold(
      backgroundColor: Colors.black,
      body: isStreaming
          ? _buildStreamViewport(context, provider)
          : _buildWaitingView(context, provider),
    );
  }

  Widget _buildStreamViewport(BuildContext context, ReceiverProvider provider) {
    final state = provider.state;
    final activeDevice = state.activeDevice;
    final strings = provider.settings.tr(context);

    double textureWidth = 1920.0;
    double textureHeight = 1080.0;
    final resParts = state.stats.resolution.split('x');
    if (resParts.length == 2) {
      final w = double.tryParse(resParts[0]);
      final h = double.tryParse(resParts[1]);
      if (w != null && h != null && w > 0 && h > 0) {
        textureWidth = w;
        textureHeight = h;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Texture Canvas (Native Hardware Texture or Video fallback)
          Center(
            child: RotatedBox(
              quarterTurns: state.rotationAngle ~/ 90,
              child: AspectRatio(
                aspectRatio: textureWidth / textureHeight,
                child: state.textureId != null
                    ? Texture(
                        textureId: state.textureId!,
                        filterQuality: FilterQuality.medium,
                      )
                    : Video(
                        controller: provider.streamService.controller,
                        controls: NoVideoControls,
                      ),
              ),
            ),
          ),

          // 2. Real-time Stream HUD overlay
          if (provider.settings.showStreamHud && state.showHud)
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: StreamHud(
                  stats: state.stats,
                  deviceName: activeDevice?.name ?? 'Android',
                  streamDuration: activeDevice != null
                      ? DateTime.now().difference(activeDevice.connectedAt)
                      : null,
                  onClose: () => provider.toggleHud(),
                ),
              ),
            ),

          // 3. Hover Floating Controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            bottom: _isHovering ? 24 : -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mute / Volume
                    IconButton(
                      icon: Icon(
                        state.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      tooltip: state.isMuted ? strings.tooltipMute : strings.tooltipUnmute,
                      onPressed: () => provider.toggleMute(),
                    ),
                    SizedBox(
                      width: 90,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: state.volume,
                          onChanged: (val) => provider.setVolume(val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Rotate
                    IconButton(
                      icon: const Icon(Icons.rotate_right, color: Colors.white),
                      tooltip: strings.tooltipRotate(state.rotationAngle),
                      onPressed: () => provider.rotateScreen(),
                    ),

                    // Toggle HUD
                    IconButton(
                      icon: Icon(
                        state.showHud ? Icons.speed : Icons.speed_outlined,
                        color: state.showHud ? Theme.of(context).colorScheme.primary : Colors.white,
                      ),
                      tooltip: strings.tooltipHud,
                      onPressed: () => provider.toggleHud(),
                    ),

                    // Fullscreen
                    IconButton(
                      icon: Icon(
                        state.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      tooltip: state.isFullScreen ? strings.tooltipFullscreenExit : strings.tooltipFullscreenEnter,
                      onPressed: () => provider.toggleFullScreen(),
                    ),

                    const SizedBox(width: 8),
                    Container(width: 1, height: 24, color: Colors.white24),
                    const SizedBox(width: 8),

                    // Disconnect
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(strings.btnDisconnect),
                      onPressed: () => provider.disconnectActiveDevice(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView(BuildContext context, ReceiverProvider provider) {
    final theme = Theme.of(context);
    final state = provider.state;
    final strings = provider.settings.tr(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar Cast Pulse Animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.cast_connected_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Main Title
            Text(
              strings.waitingTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle instructions
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                strings.waitingSubtitle(provider.settings.receiverName, provider.localIp),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info Badges (IP, Ports, Device Name)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                M3StatCard(
                  icon: Icons.computer,
                  title: strings.statReceiverName,
                  value: provider.settings.receiverName,
                  accentColor: theme.colorScheme.primary,
                ),
                M3StatCard(
                  icon: Icons.wifi,
                  title: strings.statLanIp,
                  value: provider.localIp,
                  subtitle: strings.statPorts(provider.settings.castPort, provider.settings.miracastPort),
                  accentColor: Colors.blueAccent,
                ),
                M3StatCard(
                  icon: Icons.hub,
                  title: strings.statDiscovery,
                  value: state.status == ReceiverStatus.ready ? strings.statDiscoveryActive : strings.statDiscoveryStarting,
                  accentColor: Colors.greenAccent,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await provider.stopReceiver();
                    await provider.startReceiver();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(strings.btnRestartReceiver),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
