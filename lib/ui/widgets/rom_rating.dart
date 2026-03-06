import 'package:flutter/material.dart';

class RomRating extends StatelessWidget {
  final String? rating;
  final double size;
  const RomRating({super.key, this.rating, this.size = 10});

  @override
  Widget build(BuildContext context) {
    if (rating == null || rating!.isEmpty) {
      return SizedBox.shrink();
    }
    return Opacity(
      opacity: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: Colors.yellow[600],
              size: size,
            ),
            SizedBox(
              width: 4,
            ),
            Text(
              rating!,
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
    ;
  }
}
