import 'dart:io';

import 'package:flutter/material.dart';

class AnimalPhotoViewer extends StatelessWidget {
  final String fotoPath;

  const AnimalPhotoViewer({super.key, required this.fotoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.file(
            File(fotoPath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Não foi possível abrir a foto.',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
