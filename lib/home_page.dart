import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphist/graph/base/node.dart';
import 'package:graphist/widgets/graph_controller.dart';
import 'package:graphist/widgets/graph_widget.dart';
import 'package:graphist_wiki_data/graphist_wiki_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'details_drawer.dart';
import 'dialog_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  final gc = GraphController();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  Node? selectedNode;

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    gc.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    exitPrompt(context);
  }

  Future<String?> showWikiDataSearchResultList(
    BuildContext context,
    String title,
    List<WikiDataSearchResult> options,
  ) async {
    String? result;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          actionsOverflowAlignment: OverflowBarAlignment.start,
          actionsOverflowButtonSpacing: 10,
          title: Text(title),
          actions: options.map<Widget>(
            (e) {
              return ElevatedButton(
                child: Text(e.snippet),
                onPressed: () {
                  result = e.entityId;
                  Navigator.pop(context);
                },
              );
            },
          ).toList(),
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text("WikiData Graph"),
        // Hide end drawer button
        actions: const [SizedBox()],
      ),
      drawerEnableOpenDragGesture: false,
      endDrawerEnableOpenDragGesture: false,
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: SizedBox(
                height: 1500,
                child: Center(
                  child: Text(
                    "WikiData Graph",
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text("Search"),
              onTap: () async {
                Navigator.pop(context);
                final query =
                    await DialogUtils.showTextInputDialog(context, "Search");
                if (query == null || query.trim().isEmpty) return;
                final searchResults = await WikiDataUtils.searchWikiData(query);
                if (searchResults.isNotEmpty && mounted) {
                  final selected = await showWikiDataSearchResultList(
                    context,
                    "Search results for `$query`",
                    searchResults,
                  );
                  if (selected == null) return;
                  final node =
                      await WikiDataEntityNode.tryFromWikidata(selected);
                  if (node == null) return;
                  gc.showNode(
                    node,
                    const Rect.fromLTWH(100, 100, 175, 50),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text("About"),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: "WikiData Graph",
                applicationLegalese: "Copyright 2023\nwww.amin-ahmadi.com",
                applicationVersion: "1.0.0",
              ),
            )
          ],
        ),
      ),
      endDrawer: DetailsDrawer(
        node: selectedNode,
        onOpen: () {
          if (selectedNode!.url != null) {
            launchUrl(Uri.parse(selectedNode!.url!));
          }
        },
        onCopy: () {
          String data = selectedNode!.url!;
          Clipboard.setData(ClipboardData(text: data));
          DialogUtils.showSnackBar(
            context,
            "Data copied to clipboard!\n$data",
            Colors.amber,
          );
        },
        onHide: () {
          gc.hideNode(selectedNode!.id);
        },
        details: selectedNode != null
            ? ListTile(
                title: Text(
                  (selectedNode as WikiDataEntityNode).description ?? "",
                ),
                subtitle: Text((selectedNode as WikiDataEntityNode).wikiUrl),
              )
            : const ListTile(),
      ),
      body: GraphWidget(
        controller: gc,
        onNodeLongPress: (node) {
          if (node.url != null) {
            launchUrl(Uri.parse(node.url!));
          }
        },
        onNodeSecondaryTap: (node) {
          setState(() {
            selectedNode = node;
          });
          scaffoldKey.currentState?.openEndDrawer();
        },
      ),
    );
  }

  static void exitPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Do you want to quit exploring?'),
          actions: [
            TextButton(
              child: const Text(
                'No',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Sure',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await windowManager.destroy();
              },
            ),
          ],
        );
      },
    );
  }
}
