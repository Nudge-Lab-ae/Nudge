// lib/services/social_universe_service.dart
import 'dart:math';
import '../models/contact.dart';
import '../models/social_group.dart';

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

  // Calculate CDI for a contact with dynamic weighting based on data confidence
  double calculateCDI(
    Contact contact, {
    required Map<String, SocialGroup> socialGroups,
    required List<SocialGroup> groupsList,
  }) {
    // Determine if this contact has meaningful interaction data
    final bool hasRecentInteraction = DateTime.now()
        .difference(contact.lastContacted)
        .inDays < 90;
    
    final bool hasMultipleInteractions = contact.interactionCountInWindow > 2;
    final bool hasMeaningfulData = hasRecentInteraction && hasMultipleInteractions;
    
    // Calculate base scores
    final double recencyScore = _calculateRecencyScore(contact);
    final double consistencyScore = _calculateConsistencyScore(contact);
    
    // Calculate group priority score using actual groups
    final double groupPriorityScore = _calculateGroupPriorityScore(
      contact, 
      socialGroups: socialGroups,
      groupsList: groupsList,
    );
    
    // VIP bonus
    final double vipBonus = contact.isVIP ? 20.0 : 0.0;
    
    // Calculate data confidence (0.0 - 1.0)
    // Lower confidence = more weight on group priority
    double dataConfidence = 0.0;
    
    if (hasMeaningfulData) {
      // Good data - high confidence
      dataConfidence = 0.8;
    } else if (hasRecentInteraction || hasMultipleInteractions) {
      // Some data - medium confidence
      dataConfidence = 0.5;
    } else {
      // Minimal or no data - low confidence
      dataConfidence = 0.2;
    }
    
    // Adjust confidence based on consistency score
    // If consistency score is low (<40), reduce confidence
    if (consistencyScore < 40) {
      dataConfidence *= 0.6; // Reduce confidence by 40%
    }
    
    // Calculate weights
    final double interactionWeight = dataConfidence; // Recency+Consistency weight
    final double groupWeight = 1.0 - dataConfidence; // Group priority weight
    
    // Combine recency and consistency (75% recency, 25% consistency as before)
    final double interactionScore = (0.75 * recencyScore) + (0.25 * consistencyScore);
    
    // Calculate final CDI with weighted combination
    double rawCDI = (interactionWeight * interactionScore) + 
                    (groupWeight * groupPriorityScore) + 
                    vipBonus;
    
    // Ensure VIP status always gives at least a minimum CDI
    if (contact.isVIP && rawCDI < 70) {
      rawCDI = 70.0; // VIP floor
    }
    
    // Clamp to 15-100 range
    return max(CDI_FLOOR, min(CDI_CEILING, rawCDI));
  }
  
  // Calculate group priority score based on actual group data
  double _calculateGroupPriorityScore(
    Contact contact, {
    required Map<String, SocialGroup> socialGroups,
    required List<SocialGroup> groupsList,
  }) {
    // VIP always gets highest priority
    if (contact.isVIP) {
      return 95.0;
    }
    
    // Find the contact's group by connectionType
    if (contact.connectionType.isNotEmpty) {
      final contactGroup = socialGroups[contact.connectionType];
      
      if (contactGroup != null) {
        int groupLength = groupsList.length;
        
        // Map orderIndex to priority score (0-100)
        // Lower orderIndex = higher priority (top of list)
        if (contactGroup.orderIndex <= (groupLength / 3).toInt()) {
          return 85.0; // Inner circle group
        } else if (contactGroup.orderIndex <= (groupLength / 1.5).toInt()) {
          return 60.0; // Middle circle group
        } else {
          return 35.0; // Outer circle group
        }
      }
    }
    
    // Fallback to frequency if group not found
    if (contact.frequency >= 4) return 85.0;
    if (contact.frequency >= 2) return 60.0;
    return 35.0;
  }
  
  double _calculateRecencyScore(Contact contact) {
    final now = DateTime.now();
    final lastInteraction = contact.lastContacted;
    
    // If this is a new contact with default lastContacted (today)
    // or if lastContacted is in the future
    if (lastInteraction.isAfter(now) || 
        (lastInteraction.day == now.day && 
         lastInteraction.month == now.month && 
         lastInteraction.year == now.year)) {
      return CDI_CEILING; // Just added, treat as just contacted
    }
    
    final daysSinceLastInteraction = now.difference(lastInteraction).inDays.toDouble();
    final targetInterval = contact.targetIntervalDays;
    
    // New contact with very recent first interaction
    if (contact.interactionCountInWindow <= 1 && daysSinceLastInteraction < 7) {
      return 90.0; // Give benefit of the doubt to new contacts
    }
    
    // On time or early (within target interval)
    if (daysSinceLastInteraction <= targetInterval) {
      // Map from 0-targetInterval days to 70-100
      final position = daysSinceLastInteraction / targetInterval;
      return 70.0 + (30.0 * (1 - position)); // Starts at 100, goes to 70
    }
    
    // Late but not extreme (1-4x target interval)
    if (daysSinceLastInteraction <= (targetInterval * 4)) {
      // Map from targetInterval to 4*targetInterval, from 70 down to 10
      final lateFactor = (daysSinceLastInteraction - targetInterval) / (targetInterval * 3);
      return 70.0 - (60.0 * lateFactor); // 70 → 10
    }
    
    // Very late (more than 4x target interval)
    return 10.0; // Floor
  }
  
  double _calculateConsistencyScore(Contact contact) {
    final interactionCount = contact.interactionCountInWindow;
    
    // Bucket mapping for consistency - adjusted ranges for new contacts
    if (interactionCount == 0) return 30.0;
    if (interactionCount == 1) return 50.0;
    if (interactionCount <= 2) return 65.0;
    if (interactionCount <= 5) return 80.0;
    return 95.0; // 6+ interactions
  }
  
  // Determine raw band based on CDI
  String getRawBand(double cdi) {
    if (cdi >= INNER_THRESHOLD) return 'inner';
    if (cdi >= MIDDLE_THRESHOLD) return 'middle';
    return 'outer';
  }
  
  // Calculate computed ring based on VIP status, social groups, and interaction data
  String calculateComputedRing(
    Contact contact, {
    required Map<String, SocialGroup> socialGroups,
    required List<SocialGroup> groupsList,
  }) {
    // STEP 1: VIP always inner circle
    if (contact.isVIP) {
      return 'inner';
    }
    
    // STEP 2: Find the contact's group by connectionType
    SocialGroup? contactGroup;
    if (contact.connectionType.isNotEmpty) {
      contactGroup = socialGroups[contact.connectionType];
    }
    
    // STEP 3: Determine group-based ring using orderIndex
    String groupBasedRing = 'outer'; // default
    if (contactGroup != null) {
      int groupLength = groupsList.length;
      if (contactGroup.orderIndex <= (groupLength / 3).toInt()) {
        groupBasedRing = 'inner';
      } else if (contactGroup.orderIndex <= (groupLength / 1.5).toInt()) {
        groupBasedRing = 'middle';
      } else {
        groupBasedRing = 'outer';
      }
      print('group found successfully');
      print(contactGroup.orderIndex); 
      print(groupLength);
    } else {
      // Fallback if group not found - use frequency as proxy
      print('group not found unfortunately');
      if (contact.frequency >= 4) {
        groupBasedRing = 'inner';
      } else if (contact.frequency >= 2) {
        groupBasedRing = 'middle';
      } else {
        groupBasedRing = 'outer';
      }
    }
    
    // STEP 4: Calculate interaction-based ring
    String interactionBasedRing = 'outer';
    if (contact.cdi >= 70) {
      interactionBasedRing = 'inner';
    } else if (contact.cdi >= 40) {
      interactionBasedRing = 'middle';
    } else {
      interactionBasedRing = 'outer';
    }
    
    // STEP 5: Determine if we have meaningful interaction data
    bool hasMeaningfulInteractions = contact.interactionCountInWindow > 5;
    
    // STEP 6: Calculate final ring with weighting
    if (!hasMeaningfulInteractions) {
      // No meaningful data yet - use group priority
      // print('No meaningful data');
      // print(contact.name); print(contact.cdi); print(contact.computedRing);
      // print(groupBasedRing);
      return groupBasedRing;
    } else {
      // Have some data - weight based on interaction count (max 70% interaction)
      double interactionWeight = (contact.interactionCountInWindow / 20).clamp(0.2, 0.7);
      double groupWeight = 1.0 - interactionWeight;
      
      // Convert rings to numbers for weighted average
      int groupVal = groupBasedRing == 'inner' ? 3 : groupBasedRing == 'middle' ? 2 : 1;
      int interactionVal = interactionBasedRing == 'inner' ? 3 : interactionBasedRing == 'middle' ? 2 : 1;
      
      double weightedAvg = (groupVal * groupWeight) + (interactionVal * interactionWeight);
      int roundedVal = weightedAvg.round().clamp(1, 3);
       print('Yes meaningful data');
      print(contact.name); print(contact.interactionCountInWindow);
      print(roundedVal);
      return roundedVal == 3 ? 'inner' : roundedVal == 2 ? 'middle' : 'outer';
    }
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
  Contact updateContactCDI(
    Contact contact, {
    required Map<String, SocialGroup> socialGroups,
    required List<SocialGroup> groupsList,
  }) {
    // Calculate CDI with groups
    final newCDI = calculateCDI(
      contact,
      socialGroups: socialGroups,
      groupsList: groupsList,
    );
    
    final newRawBand = getRawBand(newCDI);
    final now = DateTime.now();
    
    // Check if raw band changed
    bool rawBandChanged = newRawBand != contact.rawBand;
    
    // Calculate new computed ring using groups
    final newComputedRing = calculateComputedRing(
      contact.copyWith(cdi: newCDI),
      socialGroups: socialGroups,
      groupsList: groupsList,
    );
    
    return contact.copyWith(
      cdi: newCDI,
      rawBand: newRawBand,
      rawBandSince: rawBandChanged ? now : contact.rawBandSince,
      computedRing: newComputedRing,
      // Generate angle if not already set
      angleDeg: contact.angleDeg == 0 ? generateStableAngle(contact.id) : contact.angleDeg,
    );
  }
}