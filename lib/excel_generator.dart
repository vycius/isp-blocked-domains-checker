import 'dart:io';

import 'package:blocked_domains_checker/main.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:tuple/tuple.dart';

class ExcelGeneratorSheet {
  late Worksheet sheet;

  int row = 1;
  int column = 1;

  ExcelGeneratorSheet(Workbook workbook, String name) {
    sheet = workbook.worksheets.addWithName(name);
  }

  Range get _currentRange => sheet.getRangeByIndex(row, column);

  void _advanceRow([int advance = 1]) {
    row += advance;
  }

  void _nextCol() {
    column += 1;
    row = 1;
  }

  void _writeHeader(String header, double? columnWidth) {
    if (column != 1 || row != 1) {
      _nextCol();
    }

    _currentRange
      ..setText(header)
      ..columnWidth = columnWidth ?? 20
      ..cellStyle.bold = true;

    _advanceRow();
  }

  void writeMergedColumn<T>({
    required String header,
    required Iterable<T> items,
    required int Function(Range range, T item) writer,
    double? columnWidth,
  }) {
    _writeHeader(header, columnWidth);

    for (final item in items) {
      final advance = writer(_currentRange, item);

      assert(advance > 0, 'Invalid advance returned');

      sheet.getRangeByIndex(row, column, row + advance - 1).merge();

      _advanceRow(advance);
    }
  }

  void writeColumn<T>({
    required String header,
    required Iterable<T> items,
    required void Function(Range range, T item) writer,
    double? columnWidth,
  }) {
    return writeMergedColumn<T>(
      header: header,
      columnWidth: columnWidth,
      items: items,
      writer: (range, item) {
        writer(range, item);

        return 1;
      },
    );
  }

  void applyGlobalStyle() {
    sheet.getRangeByIndex(1, 1, row, column).cellStyle
      ..hAlign = HAlignType.center
      ..vAlign = VAlignType.center
      ..wrapText = true;
  }
}

class ExcelReportBuilder {
  static const _dateTimeFormat = '[\$-x-sysdate]yyyy-MM-dd HH:mm';

  final BuildContext context;
  final Workbook _workbook;

  ExcelReportBuilder({required this.context}) : _workbook = Workbook(0);

  Future<File> buildFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final fullPath = '${directory.path}/$fileName';

    final bytes = _workbook.saveAsStream();
    final file = File(fullPath)..writeAsBytes(bytes, flush: true);

    _workbook.dispose();

    return file;
  }

  Iterable<Tuple2<ResolvedDomain, Institution>> _flattenResolvedDomains(
    List<Institution> institutions,
    List<List<ResolvedDomain>> resolvedDomainsByInstitution,
  ) sync* {
    for (var i = 0; i < institutions.length; i++) {
      for (final resolvedDomain in resolvedDomainsByInstitution[i]) {
        yield Tuple2<ResolvedDomain, Institution>(
          resolvedDomain,
          institutions[0],
        );
      }
    }
  }

  void writeResolvedDomains(
    ExcelGeneratorSheet sheet,
    Iterable<Institution> institutions,
    Iterable<List<ResolvedDomain>> resolvedDomainsByInstitution,
  ) {
    final flattenResolvedDomains = _flattenResolvedDomains(
      institutions.toList(),
      resolvedDomainsByInstitution.toList(),
    ).toList();

    print("flattenResolvedDomains ${flattenResolvedDomains.length}");

    sheet.writeColumn<Tuple2<ResolvedDomain, Institution>>(
      header: 'Domenas',
      items: flattenResolvedDomains,
      writer: (range, resolvedDomain) {
        range.setText(resolvedDomain.item1.domain);
      },
    );

    sheet.writeColumn<Tuple2<ResolvedDomain, Institution>>(
      header: 'Statusas',
      items: flattenResolvedDomains,
      writer: (range, resolvedDomain) {
        range.setText(resolvedDomain.item1.status.name);
      },
    );

    sheet.writeColumn<Tuple2<ResolvedDomain, Institution>>(
      header: 'Institucija',
      items: flattenResolvedDomains,
      writer: (range, resolvedDomain) {
        range.setText(resolvedDomain.item2.name);
      },
    );

    sheet.writeColumn<Tuple2<ResolvedDomain, Institution>>(
      header: 'IP',
      items: flattenResolvedDomains,
      writer: (range, resolvedDomain) {
        range.setText(resolvedDomain.item1.resolvedIps.join(", "));
      },
    );

    sheet.writeColumn<Tuple2<ResolvedDomain, Institution>>(
      header: 'Data ir laikas',
      items: flattenResolvedDomains,
      writer: (range, resolvedDomain) {
        range.setDateTime(DateTime.now().toLocal());
      },
    );
  }
}
