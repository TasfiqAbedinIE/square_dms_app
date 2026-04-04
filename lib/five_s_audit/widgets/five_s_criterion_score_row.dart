import 'package:flutter/material.dart';

import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';

class FiveSCriterionScoreRow extends StatelessWidget {
  final FiveSCriterion criterion;
  final int? selectedScore;
  final bool issueFlag;
  final ValueChanged<int?> onScoreChanged;
  final ValueChanged<bool> onIssueChanged;

  const FiveSCriterionScoreRow({
    super.key,
    required this.criterion,
    required this.selectedScore,
    required this.issueFlag,
    required this.onScoreChanged,
    required this.onIssueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B1C32),
                    height: 1.3,
                  ),
                ),
                if (criterion.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    criterion.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF786E68),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: DropdownButtonFormField<int>(
              initialValue: selectedScore,
              decoration: InputDecoration(
                labelText: 'Score',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE6E0DC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE6E0DC)),
                ),
              ),
              items: [
                for (int score = 0; score <= criterion.maxScore; score++)
                  DropdownMenuItem<int>(
                    value: score,
                    child: Text('$score/${criterion.maxScore}'),
                  ),
              ],
              onChanged: onScoreChanged,
              validator: (value) => value == null ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Issue',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5C524C),
                  ),
                ),
                Switch.adaptive(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: issueFlag,
                  onChanged: onIssueChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
