import 'package:flutter/material.dart';

class VIPBadge extends StatelessWidget {
  final double size;
  final Color color;

  const VIPBadge({
    super.key,
    this.size = 20.0,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: size - 4,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            'VIP',
            style: TextStyle(
              color: Colors.white,
              fontSize: size - 6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}