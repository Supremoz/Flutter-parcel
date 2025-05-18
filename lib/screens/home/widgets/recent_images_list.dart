import 'package:flutter/material.dart';

class RecentImagesList extends StatelessWidget {
  final List<String> recentImages;
  final Function(BuildContext, String, int) onImageTap;

  const RecentImagesList({
    Key? key,
    required this.recentImages,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentImages.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              onImageTap(context, recentImages[index], index);
            },
            child: Container(
              width: 100,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: AssetImage(recentImages[index]),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}