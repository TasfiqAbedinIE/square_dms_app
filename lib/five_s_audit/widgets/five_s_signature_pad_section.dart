import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FiveSSignaturePadSection extends StatelessWidget {
  final SignatureController controller;
  final VoidCallback onClear;

  const FiveSSignaturePadSection({
    super.key,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Production Representative Signature',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B1C32),
                ),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E0DC)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Submission stays disabled until this sign-off is captured.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7A716B)),
        ),
      ],
    );
  }
}
