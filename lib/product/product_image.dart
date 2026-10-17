import 'package:flutter/material.dart';
import '../helper/image_helper.dart';

/// แสดงรูปสินค้า ถ้าไม่มีรูปหรือไฟล์หาย จะแสดงไอคอนแทน
class ProductImage extends StatelessWidget {
  final String? imageFile;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.imageFile,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final placeholder = Container(
      width: width,
      height: height,
      color: cs.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: iconSize,
        color: cs.onSecondaryContainer,
      ),
    );

    final file = ImageHelper.fileFor(imageFile);
    if (file == null) return placeholder;

    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: 600,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
