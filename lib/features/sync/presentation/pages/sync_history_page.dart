import 'package:flutter/material.dart';

class SyncHistoryPage extends StatelessWidget {
  const SyncHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步历史')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('阶段 1 只建立了页面骨架。后续阶段会在这里接入同步任务列表、状态、错误和变更摘要。'),
          ),
        ),
      ),
    );
  }
}
