import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

class AddressCameraHelper {
  static Future<File?> cropImage(String imagePath) async {
    final cropped = await ImageCropper().cropImage(sourcePath: imagePath);
    return cropped != null ? File(cropped.path) : null;
  }

  static Future<File> overlayText(File imageFile, String text) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      print("Unable overlay text");
      return imageFile;
    }
    int width = image.width;
    int height = image.height;
    int fontSize = (width * 0.05).toInt();
    final fontZipFile = await rootBundle.load('assets/font.zip');
    final font = img.BitmapFont.fromZip(fontZipFile.buffer.asUint8List());
    font.size = fontSize;
    int boxHeight = fontSize * (text.split("\n").length + 1);

    img.fillRect(
      image,
      x1: 0,
      y1: height - boxHeight,
      x2: width,
      y2: height,
      color: img.ColorRgba8(0, 0, 0, 153),
    );

    img.drawString(
      image,
      x: 20,
      y: height - boxHeight + 10,
      text,
      wrap: true,
      color: img.ColorRgba8(255, 255, 255, 255),
      font: font,
    );
    var modifiedBytes = Uint8List.fromList(img.encodeJpg(image));

    final newFile = File(imageFile.path);
    await newFile.writeAsBytes(modifiedBytes);
    return newFile;
  }
}
