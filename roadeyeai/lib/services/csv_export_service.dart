import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/violation_model.dart';

class CsvExportService {
  // Export violations to CSV
  static Future<String?> exportViolationsToCSV(List<Violation> violations) async {
    try {
      // Create CSV content
      StringBuffer csvContent = StringBuffer();
      
      // Add headers
      csvContent.writeln(Violation.csvHeaders().join(','));
      
      // Add data rows
      for (var violation in violations) {
        csvContent.writeln(violation.toCsvRow().map((e) => '"$e"').join(','));
      }
      
      // Get directory to save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/violations_$timestamp.csv';
      
      // Write to file
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());
      
      return filePath;
    } catch (e) {
      print('Error exporting CSV: $e');
      return null;
    }
  }
  
  // Export single violation
  static Future<String?> exportSingleViolation(Violation violation) async {
    try {
      StringBuffer csvContent = StringBuffer();
      
      // Add headers
      csvContent.writeln(Violation.csvHeaders().join(','));
      
      // Add data
      csvContent.writeln(violation.toCsvRow().map((e) => '"$e"').join(','));
      
      // Get directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/violation_${violation.id}_$timestamp.csv';
      
      // Write file
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());
      
      return filePath;
    } catch (e) {
      print('Error exporting CSV: $e');
      return null;
    }
  }
}