import 'dart:convert';
import 'package:crypto/crypto.dart';

String hashPassword(String plainTextPassword) {
  var bytes = utf8.encode(plainTextPassword);
  var digest = sha256.convert(bytes);
  return digest.toString();
}