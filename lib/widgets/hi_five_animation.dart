// import 'package:flutter/material.dart';
// import 'package:animations_plus/animations_plus.dart';

// class HiFiveAnimation extends StatefulWidget {
//   const HiFiveAnimation({Key? key}) : super(key: key);

//   @override
//   State<HiFiveAnimation> createState() => _HiFiveAnimationState();
// }

// class _HiFiveAnimationState extends State<HiFiveAnimation>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..forward();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           // Left hand sliding in
//           SlideInLeft(
//             duration: const Duration(seconds: 2),
//             curve: Curves.easeOutBack,
//             child: ScaleTransition(
//               scale: CurvedAnimation(
//                 parent: _controller,
//                 curve: Curves.elasticOut,
//               ),
//               child: const Icon(
//                 Icons.pan_tool,
//                 size: 100,
//                 color: Theme.of(context).colorScheme.secondary,
//               ),
//             ),
//           ),
//           // Right hand sliding in
//           SlideInRight(
//             duration: const Duration(seconds: 2),
//             curve: Curves.easeOutBack,
//             child: ScaleTransition(
//               scale: CurvedAnimation(
//                 parent: _controller,
//                 curve: Curves.elasticOut,
//               ),
//               child: const Icon(
//                 Icons.pan_tool,
//                 size: 100,
//                 color: Theme.of(context).colorScheme.error,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
