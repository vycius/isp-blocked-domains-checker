// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const blockedDomainsUrl =
      'https://raw.githubusercontent.com/vycius/isp-blocked-domains-lt/main/isp-blocked-domains.json';

  Future<List<InstitutionAndBlockedDomains>>
      _getInstitutionsAndBlockedDomains() async {
    final response = await http.get(Uri.parse(blockedDomainsUrl));

    return parseInstitutionsAndBlockedDomains(response.body);
  }

  List<InstitutionAndBlockedDomains> parseInstitutionsAndBlockedDomains(
    String responseBody,
  ) {
    return List<InstitutionAndBlockedDomains>.from(
      json
          .decode(responseBody)
          .map((x) => InstitutionAndBlockedDomains.fromJson(x)),
      growable: false,
    );
  }

  @override
  void initState() {
    super.initState();

    Intl.defaultLocale = 'lt';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blokuoti domenai',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: FutureBuilder<List<InstitutionAndBlockedDomains>>(
        future: _getInstitutionsAndBlockedDomains(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return BlockedDomainsComponent(
              institutionsAndBlockedDomains: snapshot.requireData,
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Klaida: ${snapshot.error}'),
              ),
            );
          }

          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

class BlockedDomainsComponent extends StatelessWidget {
  final List<InstitutionAndBlockedDomains> institutionsAndBlockedDomains;

  const BlockedDomainsComponent({
    Key? key,
    required this.institutionsAndBlockedDomains,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: institutionsAndBlockedDomains.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Blokuoti domenai'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final institutionAndBlockedDomains
                  in institutionsAndBlockedDomains)
                Tab(
                  text: institutionAndBlockedDomains.institution.name
                      .toUpperCase(),
                ),
              const Tab(text: 'DNS'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final institutionAndBlockedDomains
                in institutionsAndBlockedDomains)
              InstitutionAndBlockedDomainsTab(
                institutionAndBlockedDomains: institutionAndBlockedDomains,
              ),
            const DNSServerTab(),
          ],
        ),
      ),
    );
  }
}

class DNSServerTab extends StatelessWidget {
  const DNSServerTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const WebView(
      initialUrl: 'https://browserleaks.com/dns',
      javascriptMode: JavascriptMode.unrestricted,
    );
  }
}

class InstitutionAndBlockedDomainsTab extends StatelessWidget {
  final InstitutionAndBlockedDomains institutionAndBlockedDomains;

  const InstitutionAndBlockedDomainsTab({
    Key? key,
    required this.institutionAndBlockedDomains,
  }) : super(key: key);

  get blockIps => institutionAndBlockedDomains.institution.blockIps;

  Future<ResolvedDomain> resolveDomain(
    BlockedDomain blockedDomain, {
    int retriesLeft = 3,
  }) async {
    if (!blockedDomain.recordExists) {
      return ResolvedDomain(
        blockedDomain: blockedDomain,
        resolvedIps: [],
        status: DomainStatus.nx,
      );
    }

    await Future.delayed(Duration(milliseconds: Random().nextInt(30)));

    try {
      final resolvedLookup = await InternetAddress.lookup(
        blockedDomain.domain,
        type: InternetAddressType.IPv4,
      );

      final resolvedIps = resolvedLookup.map((e) => e.address).toList();

      if (resolvedIps.any((r) => blockIps.contains(r))) {
        return ResolvedDomain(
          blockedDomain: blockedDomain,
          resolvedIps: resolvedIps,
          status: DomainStatus.blocked,
        );
      } else {
        return ResolvedDomain(
          blockedDomain: blockedDomain,
          resolvedIps: resolvedIps,
          status: DomainStatus.available,
        );
      }
    } on SocketException {
      if (retriesLeft == 0) {
        return ResolvedDomain(
          blockedDomain: blockedDomain,
          resolvedIps: [],
          status: DomainStatus.error,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        return resolveDomain(blockedDomain, retriesLeft: retriesLeft - 1);
      }
    }
  }

  Future<List<ResolvedDomain>> resolveDomains() {
    final resolvedDomains = institutionAndBlockedDomains.blockedDomains
        .map((d) => resolveDomain(d));

    return Future.wait(resolvedDomains);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResolvedDomain>>(
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return BlockedDomainsListComponent(
            resolvedDomains: snapshot.requireData,
            institution: institutionAndBlockedDomains.institution,
          );
        } else {
          return Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Prašome palaukti...\nTikrinimo procesas gali užtrukti iki keleto minučių',
                  textAlign: TextAlign.center,
                ),
              )
            ],
          ));
        }
      },
      future: resolveDomains(),
    );
  }
}

class BlockedDomainsListComponent extends StatelessWidget {
  final List<ResolvedDomain> resolvedDomains;
  final Institution institution;

  const BlockedDomainsListComponent({
    Key? key,
    required this.resolvedDomains,
    required this.institution,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    resolvedDomains.sort((a, b) => a.status.index.compareTo(b.status.index));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _createAndOpenCsv,
        child: const Icon(Icons.save_alt),
      ),
      body: Scrollbar(
        interactive: true,
        child: ListView.separated(
          itemCount: resolvedDomains.length + 1,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return SummaryTableComponent(
                resolvedDomains: resolvedDomains,
              );
            } else {
              return ResolvedDomainComponent(
                resolvedDomain: resolvedDomains[index - 1],
              );
            }
          },
        ),
      ),
    );
  }

  Future _createAndOpenCsv() async {
    final resolvedDomainsRows = resolvedDomains
        .map((d) =>
            [d.blockedDomain.domain, d.status.name, d.resolvedIps.join(',')])
        .toList();

    final csvRows = [
      ['Domenas', 'Statusas', 'IP'],
      ...resolvedDomainsRows,
    ];

    final csv = const ListToCsvConverter().convert(csvRows);
    print(csv);

    final directory = await getApplicationDocumentsDirectory();
    final fileNameRaw =
        '${institution.name}-${DateTime.now().toIso8601String()}';
    final fileName = fileNameRaw.replaceAll(' ', '-');

    final fullPath = '${directory.path}/$fileName.csv';

    final file = await File(fullPath).writeAsString(csv, flush: true);

    return Share.shareFiles(
      [file.path],
      subject: fileNameRaw,
    );

  }
}

class SummaryTableComponent extends StatelessWidget {
  final List<ResolvedDomain> resolvedDomains;
  final _formatter = NumberFormat.decimalPercentPattern(decimalDigits: 1);

  SummaryTableComponent({
    Key? key,
    required this.resolvedDomains,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasErrors =
        resolvedDomains.any((r) => r.status != DomainStatus.error);

    return DataTable(headingRowHeight: 0, columns: <DataColumn>[
      DataColumn(label: Container()),
      DataColumn(label: Container()),
      DataColumn(label: Container()),
    ], rows: [
      for (final status in DomainStatus.values)
        if (status != DomainStatus.error || !hasErrors) _buildDataRow(status),
    ]);
  }

  DataRow _buildDataRow(DomainStatus status) {
    final count = resolvedDomains.where((r) => r.status == status).length;
    final total = resolvedDomains.length;
    final formattedPercentage = _formatter.format(count / total);

    return DataRow(
      cells: [
        DataCell(Text(status.pluralName)),
        DataCell(Text('$count')),
        DataCell(Text(formattedPercentage)),
      ],
    );
  }
}

class ResolvedDomainComponent extends StatelessWidget {
  final ResolvedDomain resolvedDomain;

  const ResolvedDomainComponent({Key? key, required this.resolvedDomain})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _getLeadingForResolvedDomain(),
      title: Text(resolvedDomain.blockedDomain.domain),
      subtitle: Text(
        "${resolvedDomain.status.name}\n"
        "${resolvedDomain.resolvedIps.join(" ")}",
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => launch(
        "http://${resolvedDomain.blockedDomain.domain}",
      ),
    );
  }

  Widget _getLeadingForResolvedDomain() {
    switch (resolvedDomain.status) {
      case DomainStatus.available:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(
            Icons.error_outline,
            color: Colors.white,
          ),
        );
      case DomainStatus.blocked:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(
            Icons.check,
            color: Colors.white,
          ),
        );
      case DomainStatus.nx:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.lightbulb,
            color: Colors.white,
          ),
        );
      case DomainStatus.error:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(
            Icons.warning_amber,
            color: Colors.white,
          ),
        );
    }
  }
}
