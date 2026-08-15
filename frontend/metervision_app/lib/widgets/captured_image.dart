import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class CapturedImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;

  const CapturedImage({super.key, required this.imagePath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Image.file(File(imagePath), fit: fit);
    }

    return FutureBuilder<Uint8List>(
      future: _fetchBlobBytes(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey));
        }
        return Image.memory(snapshot.data!, fit: fit);
      },
    );
  }

  Future<Uint8List> _fetchBlobBytes(String blobUrl) async {
    final response = await Dio().get<List<int>>(
      blobUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }
}