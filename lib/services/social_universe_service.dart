// lib/services/social_universe_service.dart
import 'dart:math';
import '../models/contact.dart';

class SocialUniverseService {
  static const double MIN_DAYS_IN_BAND = 3.0; // Minimum days before ring changes
  static const double CDI_FLOOR = 15.0;
  static const double CDI_CEILING = 100.0;
  
  // CDI Band thresholds
  static const double INNER_THRESHOLD = 80.0;
  static const double MIDDLE_THRESHOLD = 50.0;
  
  // Ring radius ranges (as percentage of max radius)
  static const double INNER_RING_MIN = 0.2;
  static const double INNER_RING_MAX = 0.4;
  static const double MIDDLE_RING_MIN = 0.5;
  static const double MIDDLE_RING_MAX = 0.7;
  static const double OUTER_RING_MIN = 0.8;
  static const double OUTER_RING_MAX = 1.0;
  
  // Node size mapping based on priority (position)
  static const Map<int, double> SIZE_FACTORS = {
    1: 1.4, // Highest priority
    2: 1.25,
    3: 1.1,
    4: 1.0,
    5: 0.9, // Lowest priority
  };

  // Calculate CDI for a contact
  double calculateCDI(Contact contact) {
    // Calculate recency score (R)
    final double recencyScore = _calculateRecencyScore(contact);
    
    // Calculate consistency score (C)
    final double consistencyScore = _calculateConsistencyScore(contact);
    
    // Combine scores: 75% recency, 25% consistency
    final double rawCDI = (0.75 * recencyScore) + (0.25 * consistencyScore);
    
    // Clamp to 15-100 range
    return max(CDI_FLOOR, min(CDI_CEILING, rawCDI));
  }
  
  double _calculateRecencyScore(Contact contact) {
    final now = DateTime.now();
    final lastInteraction = contact.lastContacted;
    
    if (lastInteraction.isAfter(now)) {
      return CDI_CEILING; // Future date, treat as just contacted
    }
    
    final daysSinceLastInteraction = now.difference(lastInteraction).inDays.toDouble();
    final targetInterval = contact.targetIntervalDays;
    
    // On time or early (within target interval)
    if (daysSinceLastInteraction <= targetInterval) {
      // Map from 0-targetInterval days to 80-100
      final position = daysSinceLastInteraction / targetInterval;
      return 80.0 + (20.0 * (1 - position)); // Starts at 100, goes to 80
    }
    
    // Late but not extreme (1-4x target interval)
    if (daysSinceLastInteraction <= (targetInterval * 4)) {
      // Map from targetInterval to 4*targetInterval, from 80 down to 10
      final lateFactor = (daysSinceLastInteraction - targetInterval) / (targetInterval * 3);
      return 80.0 - (70.0 * lateFactor); // 80 → 10
    }
    
    // Very late (more than 4x target interval)
    return 10.0; // Floor
  }
  
  double _calculateConsistencyScore(Contact contact) {
    final interactionCount = contact.interactionCountInWindow;
    
    // Bucket mapping for consistency
    if (interactionCount == 0) return 10.0;
    if (interactionCount <= 2) return 40.0;
    if (interactionCount <= 5) return 70.0;
    return 100.0; // 6+ interactions
  }
  
  // Determine raw band based on CDI
  String getRawBand(double cdi) {
    if (cdi >= INNER_THRESHOLD) return 'inner';
    if (cdi >= MIDDLE_THRESHOLD) return 'middle';
    return 'outer';
  }
  
  // Calculate computed ring with hysteresis
  String calculateComputedRing(Contact contact) {
    final rawBand = getRawBand(contact.cdi);
    final daysInRawBand = DateTime.now().difference(contact.rawBandSince).inDays.toDouble();
    
    // If already in this computed ring, keep it
    if (contact.computedRing == rawBand) {
      return contact.computedRing;
    }
    
    // If stayed in new band for minimum time, update computed ring
    if (daysInRawBand >= MIN_DAYS_IN_BAND) {
      return rawBand;
    }
    
    // Not enough time in new band, keep current computed ring
    return contact.computedRing;
  }
  
  // Calculate radius within ring based on CDI
  double calculateRadius(Contact contact, double maxRadius) {
    final ring = contact.computedRing;
    final cdi = contact.cdi;
    
    double minRadius, maxRadiusInRing, cdiMin, cdiMax;
    
    switch (ring) {
      case 'inner':
        minRadius = maxRadius * INNER_RING_MIN;
        maxRadiusInRing = maxRadius * INNER_RING_MAX;
        cdiMin = INNER_THRESHOLD;
        cdiMax = CDI_CEILING;
        break;
      case 'middle':
        minRadius = maxRadius * MIDDLE_RING_MIN;
        maxRadiusInRing = maxRadius * MIDDLE_RING_MAX;
        cdiMin = MIDDLE_THRESHOLD;
        cdiMax = INNER_THRESHOLD - 1;
        break;
      case 'outer':
        minRadius = maxRadius * OUTER_RING_MIN;
        maxRadiusInRing = maxRadius * OUTER_RING_MAX;
        cdiMin = CDI_FLOOR;
        cdiMax = MIDDLE_THRESHOLD - 1;
        break;
      default:
        return maxRadius * 0.8;
    }
    
    // Map CDI within band to radius within ring
    final cdiPosition = (cdi - cdiMin) / (cdiMax - cdiMin);
    final radiusPosition = 1 - cdiPosition; // Higher CDI = closer to center
    
    return minRadius + (radiusPosition * (maxRadiusInRing - minRadius));
  }
  
  // Calculate node size based on priority
  double calculateNodeSize(int priority) {
    return SIZE_FACTORS[priority] ?? 1.0;
  }
  
  // Generate stable angle for contact (based on ID hash)
  double generateStableAngle(String contactId) {
    if (contactId.isEmpty) return Random().nextDouble() * 360;
    
    // Create a hash from the ID
    var hash = 0;
    for (var i = 0; i < contactId.length; i++) {
      hash = contactId.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return (hash.abs() % 360).toDouble();
  }
  
  // Update contact with fresh CDI calculation
  Contact updateContactCDI(Contact contact) {
    final newCDI = calculateCDI(contact);
    final newRawBand = getRawBand(newCDI);
    final now = DateTime.now();
    
    // Check if raw band changed
    bool rawBandChanged = newRawBand != contact.rawBand;
    
    return contact.copyWith(
      cdi: newCDI,
      rawBand: newRawBand,
      rawBandSince: rawBandChanged ? now : contact.rawBandSince,
      computedRing: calculateComputedRing(contact.copyWith(
        cdi: newCDI,
        rawBand: newRawBand,
        rawBandSince: rawBandChanged ? now : contact.rawBandSince,
      )),
      // Generate angle if not already set
      angleDeg: contact.angleDeg == 0 ? generateStableAngle(contact.id) : contact.angleDeg,
    );
  }
}