import 'package:flutter/material.dart';
import '../core/models/navigation_state.dart';
import '../core/models/route.dart';

/// Navigation Heads-Up Display (HUD) overlay widget.
class NavigationHudView extends StatelessWidget {
  final NavigationState state;
  final VoidCallback? onSearchTap;
  final VoidCallback? onReCenter;
  final VoidCallback? onToggleMute;
  final VoidCallback? onStopNavigation;
  final bool isMuted;
  final bool isFreeCamera;

  const NavigationHudView({
    super.key,
    required this.state,
    this.onSearchTap,
    this.onReCenter,
    this.onToggleMute,
    this.onStopNavigation,
    this.isMuted = false,
    this.isFreeCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status == NavigationStatus.idle) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              elevation: 6.0,
              borderRadius: BorderRadius.circular(16.0),
              color: Colors.white,
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey, size: 24.0),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          'Where to go?',
                          style: TextStyle(color: Colors.black54, fontSize: 16.0, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.location_on, color: Colors.redAccent, size: 24.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Top Turn Instruction Card
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 6.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 56.0,
                    height: 56.0,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Icon(
                      _getManeuverIcon(state.maneuver),
                      color: Colors.white,
                      size: 32.0,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.formattedDistanceToNextManeuver,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          state.currentInstruction,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Rerouting Banner Alert
          if (state.isRerouting)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade800,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8.0),
                  Text(
                    'Off route. Calculating new route...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // 3. Bottom Navigation Summary Panel & Controls
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 6.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Distance & Time remaining
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.formattedDistanceRemaining,
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'ETA: ${state.eta != null ? "${state.eta!.hour.toString().padLeft(2, '0')}:${state.eta!.minute.toString().padLeft(2, '0')}" : "--:--"}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14.0),
                        ),
                      ],
                    ),
                  ),

                  // Re-center button (when panned)
                  if (isFreeCamera)
                    IconButton.filled(
                      onPressed: onReCenter,
                      icon: const Icon(Icons.my_location),
                      style: IconButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),

                  const SizedBox(width: 8.0),

                  // Mute / Unmute button
                  IconButton(
                    onPressed: onToggleMute,
                    icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
                  ),

                  const SizedBox(width: 8.0),

                  // Stop navigation button
                  IconButton.filled(
                    onPressed: onStopNavigation,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getManeuverIcon(ManeuverType type) {
    switch (type) {
      case ManeuverType.turnLeft:
        return Icons.turn_left;
      case ManeuverType.turnRight:
        return Icons.turn_right;
      case ManeuverType.turnSlightLeft:
        return Icons.turn_slight_left;
      case ManeuverType.turnSlightRight:
        return Icons.turn_slight_right;
      case ManeuverType.turnSharpLeft:
        return Icons.turn_sharp_left;
      case ManeuverType.turnSharpRight:
        return Icons.turn_sharp_right;
      case ManeuverType.uTurn:
        return Icons.u_turn_left;
      case ManeuverType.roundabout:
        return Icons.roundabout_left;
      case ManeuverType.arrive:
        return Icons.pin_drop;
      case ManeuverType.depart:
        return Icons.navigation;
      case ManeuverType.straight:
        return Icons.straight;
      case ManeuverType.unknown:
        return Icons.straight;
    }
  }
}
