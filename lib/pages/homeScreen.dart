import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool isLoading = true;

  final List<Map<String, dynamic>> cardData = [
    {'title': 'Production', 'value': 9500, 'icon': Icons.factory},
    {'title': 'Target', 'value': 10000, 'icon': Icons.flag},
    {'title': 'Achievement %', 'value': 95, 'icon': Icons.percent},
  ];

  final List<Map<String, dynamic>> tableData = [
    {'time': '8-9 AM', 'production': 1000, 'target': 1100},
    {'time': '9-10 AM', 'production': 1200, 'target': 1100},
    {'time': '10-11 AM', 'production': 900, 'target': 1100},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    _loadData();
  }

  Future<void> _loadData() async {
    await Future.delayed(Duration(seconds: 2));
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate)
      setState(() {
        selectedDate = picked;
      });
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      isLoading = true;
    });
    await _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildSeparator() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: List.generate(
          150 ~/ 5,
          (index) => Expanded(
            child: Container(
              color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("DASHBOARD")),
      drawer: AppSideBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshDashboard,
        child: Icon(Icons.refresh),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _controller,
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                Container(
                  height: 170,
                  child:
                      isLoading
                          ? Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (_, __) => CardPlaceholder(),
                            ),
                          )
                          : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: BouncingScrollPhysics(),
                            itemCount: cardData.length,
                            padding: EdgeInsets.only(right: 16),
                            itemBuilder: (context, index) {
                              return SlideTransition(
                                position: _animation,
                                child: Container(
                                  width: 180,
                                  margin: EdgeInsets.only(right: 16),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withAlpha(51),
                                        blurRadius: 10,
                                        spreadRadius: 3,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        cardData[index]['icon'],
                                        size: 40,
                                        color: Colors.blueAccent,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        cardData[index]['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        cardData[index]['value'].toString(),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),

                buildSeparator(),

                Text("Production Trend", style: sectionTitleStyle()),
                SizedBox(height: 10),
                Container(
                  height: 250,
                  padding: EdgeInsets.all(16),
                  decoration: cardBoxDecoration(),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 4,
                      minY: 0,
                      maxY: 2000,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine:
                            (value) => FlLine(
                              color: Colors.grey.withAlpha(100),
                              strokeWidth: 1,
                            ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: bottomTitleWidgets,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            FlSpot(0, 1000),
                            FlSpot(1, 1200),
                            FlSpot(2, 900),
                            FlSpot(3, 1500),
                            FlSpot(4, 1400),
                          ],
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlueAccent],
                          ),
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.lightBlueAccent.withAlpha(100),
                                Colors.blueAccent.withAlpha(100),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          dotData: FlDotData(show: true),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          // tooltipBgColor: Colors.blueAccent.withAlpha(100),
                          tooltipRoundedRadius: 8,
                          //                       getTooltipColor: TooltipStyle(
                          //   backgroundColor: Colors.blueAccent.withOpacity(0.8),
                          //   borderRadius: BorderRadius.circular(8),
                          // ),
                          getTooltipItems:
                              (spots) =>
                                  spots
                                      .map(
                                        (spot) => LineTooltipItem(
                                          '${spot.y.toInt()} pcs',
                                          TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                      .toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                buildSeparator(),

                Text("Production Details", style: sectionTitleStyle()),
                SizedBox(height: 10),
                Container(
                  decoration: cardBoxDecoration(),
                  child: DataTable(
                    columnSpacing: 35,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateColor.resolveWith(
                      (states) => Colors.blueAccent.withAlpha(204),
                    ),
                    headingTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    columns: const [
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Production')),
                      DataColumn(label: Text('Target')),
                    ],
                    rows:
                        tableData
                            .map(
                              (row) => DataRow(
                                cells: [
                                  DataCell(Text(row['time'])),
                                  DataCell(Text(row['production'].toString())),
                                  DataCell(Text(row['target'].toString())),
                                ],
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget CardPlaceholder() => Container(
    width: 180,
    margin: EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      // borderRadius: BorderRadius.circular(20),
    ),
  );

  TextStyle sectionTitleStyle() => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  BoxDecoration cardBoxDecoration() => BoxDecoration(
    color: Colors.white,
    // borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withAlpha(100),
        blurRadius: 10,
        spreadRadius: 5,
      ),
    ],
  );

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    switch (value.toInt()) {
      case 0:
        return Text('8-9');
      case 1:
        return Text('9-10');
      case 2:
        return Text('10-11');
      case 3:
        return Text('11-12');
      case 4:
        return Text('12-1');
    }
    return Text('');
  }
}
