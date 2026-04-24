import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // ─── Cloudinary Config ───────────────────────────────
  // TODO: Replace with your actual Cloudinary credentials
  static const String _cloudName = 'dltbs05w8'; // Placeholder
  static const String _uploadPreset = 'cricket_app_preset'; // Placeholder
  static const String _baseUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads an XFile to Cloudinary using HTTP multipart request.
  /// Returns the secure_url string if successful, otherwise throws an Exception.
  static Future<String> uploadImage(XFile imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      request.fields['upload_preset'] = _uploadPreset;

      // Add file to request
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        throw Exception('Cloudinary upload failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Cloudinary Service Error: $e');
    }
  }
}
