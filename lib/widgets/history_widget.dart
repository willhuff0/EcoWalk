import 'package:eco_walk/api.dart';
import 'package:eco_walk/pages/walk_recap_page.dart';
import 'package:eco_walk/widgets/leaf_count_widget.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart' as intl;

void Function()? refreshHistoryList;

class HistoryListWidget extends StatefulWidget {
  final AppState appState;

  const HistoryListWidget({super.key, required this.appState});

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  var _loading = true;
  late List<ESWalk> _walks;

  @override
  void initState() {
    refreshHistoryList = () {
      if (!mounted) return;
      _load().then((_) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      });
    };

    _load().then((_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
    super.initState();
  }

  Future<void> _load() async {
    _walks = await apiGetWalks(widget.appState);
    _walks.sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? SizedBox(
            height: 200.0,
            child: Center(child: CircularProgressIndicator()),
          )
        : ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.only(left: 14.0, right: 14.0, bottom: 14.0),
            itemCount: _walks.length,
            itemBuilder: (context, index) {
              final walk = _walks[index];

              return Card(
                clipBehavior: Clip.hardEdge,
                child: ListTile(
                  title: Text(walk.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateText(date: walk.date),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LeafCountWidget(count: walk.pois.length),
                      SizedBox(width: 4.0),
                      const Icon(BoxIcons.bx_chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => WalkRecapPage(
                          appState: widget.appState,
                          walk: walk,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
  }
}

class _DateText extends StatelessWidget {
  final DateTime date;

  const _DateText({required this.date});

  String _format() {
    final differenceDays = (date.difference(DateTime.now()).inMinutes / (24 * 60)).floor();

    String? subtext = switch (differenceDays) {
      -1 => 'Yesterday',
      0 => 'Today',
      final x when x < -1 && x > -365 => '${-x} days ago',
      _ => null,
    };

    if (differenceDays <= 7 && subtext != null) {
      return '$subtext, ${intl.DateFormat.jm().format(date)}';
    }

    var suffix = 'th';
    final digit = date.day % 10;
    if ((digit > 0 && digit < 4) && (date.day < 11 || date.day > 13)) {
      suffix = <String>['st', 'nd', 'rd'][digit - 1];
    }
    return intl.DateFormat("${subtext != null ? "'$subtext, '" : ''}MMMM d'$suffix'${differenceDays <= -365 ? ', y' : ''}, ${intl.DateFormat.jm().format(date)}").format(date);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Text(_format(), style: textTheme.bodySmall!.copyWith(color: colors.onSurfaceVariant));
  }
}
