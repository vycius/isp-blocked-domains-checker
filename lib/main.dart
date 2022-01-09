// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Užblokuoti domenai',
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
      length: institutionsAndBlockedDomains.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Užblokuoti domenai'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final institutionAndBlockedDomains
                  in institutionsAndBlockedDomains)
                Tab(
                  text: institutionAndBlockedDomains.institution.name,
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final institutionAndBlockedDomains
                in institutionsAndBlockedDomains)
              InstitutionAndBlockedDomainsTab(
                institutionAndBlockedDomains: institutionAndBlockedDomains,
              ),
          ],
        ),
      ),
    );
  }
}

class InstitutionAndBlockedDomainsTab extends StatelessWidget {
  final InstitutionAndBlockedDomains institutionAndBlockedDomains;

  get blockIps => institutionAndBlockedDomains.institution.blockIps;

  const InstitutionAndBlockedDomainsTab({
    Key? key,
    required this.institutionAndBlockedDomains,
  }) : super(key: key);

  Future<ResolvedDomain> resolveDomain(BlockedDomain blockedDomain) async {
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
    } on SocketException catch (ex) {
      return ResolvedDomain(
        blockedDomain: blockedDomain,
        resolvedIps: [],
        status: DomainStatus.error,
      );
    }
  }

  Future<List<ResolvedDomain>> resolveDomains() {
    final resolvedDomains = institutionAndBlockedDomains.blockedDomains
        .map((d) => resolveDomain(d))
        .toList();

    return Future.wait(resolvedDomains);
  }

  Widget _getLeadingForResolvedDomain(ResolvedDomain resolvedDomain) {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResolvedDomain>>(
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final items = snapshot.requireData
            ..sort((a, b) => a.status.index.compareTo(b.status.index));

          return Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final availableDomains = items
                    .where((e) => e.status == DomainStatus.available)
                    .toList();

                final domains =
                    availableDomains.map((e) => e.blockedDomain).join("\n");

                final ips = availableDomains
                    .map((e) => e.resolvedIps.join(", "))
                    .join("\n");

                await Clipboard.setData(
                  ClipboardData(text: "$domains\n\n$ips"),
                );
              },
              child: const Icon(Icons.copy_all),
            ),
            body: ListView.separated(
              itemCount: items.length + 1,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return DataTable(headingRowHeight: 0, columns: <DataColumn>[
                    DataColumn(label: Container()),
                    DataColumn(label: Container()),
                  ], rows: [
                    for (final status in DomainStatus.values)
                      DataRow(
                        cells: [
                          DataCell(Text(status.pluralName)),
                          DataCell(
                            Text(
                              items
                                  .where((r) => r.status == status)
                                  .length
                                  .toString(),
                            ),
                          ),
                        ],
                      ),
                  ]);
                }

                final resolvedDomain = items[index - 1];

                return ListTile(
                  leading: _getLeadingForResolvedDomain(resolvedDomain),
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
              },
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(snapshot.error?.toString() ?? "Unknown error");
        }

        return const Center(child: CircularProgressIndicator());
      },
      future: resolveDomains(),
    );
  }
}
